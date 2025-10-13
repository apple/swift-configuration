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
private struct TestSnapshot: ConfigSnapshotProtocol {
    var values: [String: ConfigValue]

    var providerName: String { "TestProvider" }

    func value(forKey key: AbsoluteConfigKey, type: ConfigType) throws -> LookupResult {
        let encodedKey = SeparatorKeyEncoder.dotSeparated.encode(key)
        return LookupResult(encodedKey: encodedKey, value: values[encodedKey])
    }

    init(values: [String: ConfigValue]) {
        self.values = values
    }

    init(contents: String) throws {
        var values: [String: ConfigValue] = [:]

        // Simple key=value parser for testing
        for line in contents.split(separator: "\n") {
            let parts = line.split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
                let value = String(parts[1]).trimmingCharacters(in: .whitespaces)
                values[key] = .init(.string(value), isSecret: false)
            }
        }
        self.init(values: values)
    }
}

@available(Configuration 1.0, *)
extension InMemoryFileSystem.FileData {
    static func file(contents: String) -> Self {
        .file(Data(contents.utf8))
    }
}

@available(Configuration 1.0, *)
extension InMemoryFileSystem.FileInfo {
    static func file(timestamp: Date, contents: String) -> Self {
        .init(lastModifiedTimestamp: timestamp, data: .file(contents: contents))
    }
}

@available(Configuration 1.0, *)
private func withTestProvider<R>(
    body: (
        ReloadingFileProviderCore<TestSnapshot>,
        InMemoryFileSystem,
        FilePath,
        Date
    ) async throws -> R
) async throws -> R {
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
    let core = try await ReloadingFileProviderCore<TestSnapshot>(
        filePath: filePath,
        pollInterval: .seconds(1),
        providerName: "TestProvider",
        fileSystem: fileSystem,
        logger: .noop,
        metrics: NOOPMetricsHandler.instance,
        createSnapshot: { data in
            try TestSnapshot(contents: String(decoding: data, as: UTF8.self))
        }
    )
    return try await body(core, fileSystem, filePath, originalTimestamp)
}

struct CoreTests {
    @available(Configuration 1.0, *)
    @Test func testBasicManualReload() async throws {
        try await withTestProvider { core, fileSystem, filePath, originalTimestamp in
            // Check initial values
            let result1 = try core.value(forKey: ["key1"], type: .string)
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
            try await core.reloadIfNeeded(logger: .noop)

            // Check updated value
            let result2 = try core.value(forKey: ["key1"], type: .string)
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
        let core = try await ReloadingFileProviderCore<TestSnapshot>(
            filePath: filePath,
            pollInterval: .milliseconds(1),
            providerName: "TestProvider",
            fileSystem: fileSystem,
            logger: .noop,
            metrics: NOOPMetricsHandler.instance,
            createSnapshot: { data in
                try TestSnapshot(contents: String(decoding: data, as: UTF8.self))
            }
        )

        // Check initial values
        let result1 = try core.value(forKey: ["key1"], type: .string)
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
                try await core.run()
            }
            for _ in 1..<1000 {
                let result2 = try core.value(forKey: ["key1"], type: .string)
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
        try await withTestProvider { core, fileSystem, filePath, originalTimestamp in
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
            try await core.reloadIfNeeded(logger: .noop)

            // Check initial value (from target1)
            let result1 = try core.value(forKey: ["key"], type: .string)
            #expect(try result1.value?.content.asString == "target1")

            // Change symlink to point to second target (with same timestamp)
            fileSystem.update(
                filePath: filePath,
                timestamp: originalTimestamp,
                contents: .symlink(targetPath2)
            )

            // Trigger reload - should detect the change even though timestamp is the same
            try await core.reloadIfNeeded(logger: .noop)

            // Check updated value (from target2)
            let result2 = try core.value(forKey: ["key"], type: .string)
            #expect(try result2.value?.content.asString == "target2")
        }
    }

    @available(Configuration 1.0, *)
    @Test func testSymlink_timestampChanged() async throws {
        try await withTestProvider { core, fileSystem, filePath, originalTimestamp in
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
            try await core.reloadIfNeeded(logger: .noop)

            // Check initial value (from target1)
            let result1 = try core.value(forKey: ["key"], type: .string)
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
            try await core.reloadIfNeeded(logger: .noop)

            // Check updated value (from target2)
            let result2 = try core.value(forKey: ["key"], type: .string)
            #expect(try result2.value?.content.asString == "target2")
        }
    }

    @available(Configuration 1.0, *)
    @Test func testWatchValue() async throws {
        try await withTestProvider { core, fileSystem, filePath, originalTimestamp in
            let firstValueConsumed = TestFuture<Void>(name: "First value consumed")
            let updateReceived = TestFuture<String?>(name: "Update")

            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    try await core.watchValue(forKey: ["key1"], type: .string) { updates in
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
                try await core.reloadIfNeeded(logger: .noop)

                // Wait for update
                let receivedValue = await updateReceived.value
                #expect(receivedValue == "value2")

                group.cancelAll()
            }
        }
    }
}

#endif
