//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftConfiguration open source project
//
// Copyright (c) 2025 Apple Inc. and the SwiftConfiguration project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftConfiguration project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

#if ReloadingSupport

import Testing
import ConfigurationTestingInternal
@testable import Configuration
import Foundation
import ConfigurationTesting
import Logging
import Metrics
import ServiceLifecycle
import Synchronization
import SystemPackage

@available(Configuration 1.0, *)
private func withTestProvider<R>(
    body: (
        ReloadingFileProvider<TestSnapshot>,
        InMemoryFileSystem,
        FilePath,
        Date
    ) async throws -> R
) async throws -> R {
    try await withTestFileSystem { fileSystem, filePath, originalTimestamp in
        let provider = try await ReloadingFileProvider<TestSnapshot>(
            parsingOptions: .default,
            filePath: filePath,
            pollInterval: .seconds(1),
            fileSystem: fileSystem,
            logger: .noop,
            metrics: NOOPMetricsHandler.instance
        )
        return try await body(provider, fileSystem, filePath, originalTimestamp)
    }
}

struct ReloadingFileProviderTests {
    @available(Configuration 1.0, *)
    @Test func testBasicManualReload() async throws {
        try await withTestProvider { provider, fileSystem, filePath, originalTimestamp in
            // Check initial values
            let result1 = try provider.value(forKey: ["key1"], type: .string)
            #expect(try result1.value?.content.asString == "value1")

            // Update file content
            fileSystem.update(
                filePath: filePath,
                timestamp: originalTimestamp.addingTimeInterval(1.0),
                contents: .file(
                    contents: """
                        key1=newValue1
                        key2=value2
                        """
                )
            )

            // Trigger reload
            try await provider.reloadIfNeeded(logger: .noop)

            // Check updated value
            let result2 = try provider.value(forKey: ["key1"], type: .string)
            #expect(try result2.value?.content.asString == "newValue1")
        }
    }

    @available(Configuration 1.0, *)
    @Test func testBasicTimedReload() async throws {
        let filePath = FilePath("/test/config.txt")
        let originalTimestamp = Date(timeIntervalSince1970: 1_750_688_537)
        let fileSystem = InMemoryFileSystem(
            files: [
                filePath: .file(
                    timestamp: originalTimestamp,
                    contents: """
                        key1=value1
                        key2=value2
                        """
                )
            ]
        )
        let provider = try await ReloadingFileProvider<TestSnapshot>(
            parsingOptions: .default,
            filePath: filePath,
            pollInterval: .milliseconds(1),
            fileSystem: fileSystem,
            logger: .noop,
            metrics: NOOPMetricsHandler.instance
        )

        // Check initial values
        let result1 = try provider.value(forKey: ["key1"], type: .string)
        #expect(try result1.value?.content.asString == "value1")

        // Update file content
        fileSystem.update(
            filePath: filePath,
            timestamp: originalTimestamp.addingTimeInterval(1.0),
            contents: .file(
                contents: """
                    key1=newValue1
                    key2=value2
                    """
            )
        )

        // Run the service and actively poll until we see the change
        try await withThrowingTaskGroup { group in
            group.addTask {
                try await provider.run()
            }
            for _ in 1..<1000 {
                let result2 = try provider.value(forKey: ["key1"], type: .string)
                guard try result2.value?.content.asString == "newValue1" else {
                    try await Task.sleep(for: .milliseconds(1))
                    continue
                }
                // Got the new value, cancel the group and return
                group.cancelAll()
                return
            }
            Issue.record("Timed out waiting for the update")
        }
    }

    @available(Configuration 1.0, *)
    @Test func testSymlink_targetPathChanged() async throws {
        try await withTestProvider { provider, fileSystem, filePath, originalTimestamp in
            let targetPath1 = FilePath("/test/config1.txt")
            let targetPath2 = FilePath("/test/config2.txt")

            // Create two target files with the same timestamp
            let timestamp = Date(timeIntervalSince1970: 1000)
            fileSystem.update(
                filePath: targetPath1,
                timestamp: timestamp,
                contents: .file(
                    contents: """
                        key=target1
                        """
                )
            )
            fileSystem.update(
                filePath: targetPath2,
                timestamp: timestamp,
                contents: .file(
                    contents: """
                        key=target2
                        """
                )
            )

            // Create symlink pointing to first target
            fileSystem.update(
                filePath: filePath,
                timestamp: originalTimestamp,
                contents: .symlink(targetPath1)
            )
            try await provider.reloadIfNeeded(logger: .noop)

            // Check initial value (from target1)
            let result1 = try provider.value(forKey: ["key"], type: .string)
            #expect(try result1.value?.content.asString == "target1")

            // Change symlink to point to second target (with same timestamp)
            fileSystem.update(
                filePath: filePath,
                timestamp: originalTimestamp,
                contents: .symlink(targetPath2)
            )

            // Trigger reload - should detect the change even though timestamp is the same
            try await provider.reloadIfNeeded(logger: .noop)

            // Check updated value (from target2)
            let result2 = try provider.value(forKey: ["key"], type: .string)
            #expect(try result2.value?.content.asString == "target2")
        }
    }

    @available(Configuration 1.0, *)
    @Test func testSymlink_timestampChanged() async throws {
        try await withTestProvider { provider, fileSystem, filePath, originalTimestamp in
            let targetPath = FilePath("/test/config1.txt")

            // Create two target files with the same timestamp
            let timestamp = Date(timeIntervalSince1970: 1000)
            fileSystem.update(
                filePath: targetPath,
                timestamp: timestamp,
                contents: .file(
                    contents: """
                        key=target1
                        """
                )
            )

            // Create symlink pointing to first target
            fileSystem.update(
                filePath: filePath,
                timestamp: originalTimestamp,
                contents: .symlink(targetPath)
            )
            try await provider.reloadIfNeeded(logger: .noop)

            // Check initial value (from target1)
            let result1 = try provider.value(forKey: ["key"], type: .string)
            #expect(try result1.value?.content.asString == "target1")

            // Change symlink to point to second target (with same timestamp)
            fileSystem.update(
                filePath: targetPath,
                timestamp: timestamp.addingTimeInterval(1),
                contents: .file(
                    contents: """
                        key=target2
                        """
                )
            )

            // Trigger reload
            try await provider.reloadIfNeeded(logger: .noop)

            // Check updated value (from target2)
            let result2 = try provider.value(forKey: ["key"], type: .string)
            #expect(try result2.value?.content.asString == "target2")
        }
    }

    @available(Configuration 1.0, *)
    @Test func testWatchValue() async throws {
        try await withTestProvider { provider, fileSystem, filePath, originalTimestamp in
            let firstValueConsumed = TestFuture<Void>(name: "First value consumed")
            let updateReceived = TestFuture<String?>(name: "Update")

            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    try await provider.watchValue(forKey: ["key1"], type: .string) { updates in
                        var iterator = updates.makeAsyncIterator()

                        // First value (initial)
                        let first = try await iterator.next()
                        let firstValue = try first?.get().value?.content.asString
                        #expect(firstValue == "value1")
                        firstValueConsumed.fulfill(())

                        // Second value (after update)
                        let second = try await iterator.next()
                        updateReceived.fulfill(try second?.get().value?.content.asString)
                    }
                }

                _ = await firstValueConsumed.value

                // Update file
                fileSystem.update(
                    filePath: filePath,
                    timestamp: originalTimestamp.addingTimeInterval(1),
                    contents: .file(
                        contents: """
                            key1=value2
                            """
                    )
                )

                // Trigger reload
                try await provider.reloadIfNeeded(logger: .noop)

                // Wait for update
                let receivedValue = await updateReceived.value
                #expect(receivedValue == "value2")

                group.cancelAll()
            }
        }
    }
}

#endif
