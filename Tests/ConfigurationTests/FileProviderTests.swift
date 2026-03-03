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

import Testing
import ConfigurationTestingInternal
@testable import Configuration
import Foundation
import ConfigurationTesting
import Logging
import ServiceLifecycle
import Synchronization
import SystemPackage

@available(Configuration 1.0, *)
private func withTestProvider<R>(
    body: (
        FileProvider<TestSnapshot>,
        InMemoryFileSystem,
        FilePath,
        Date
    ) async throws -> R
) async throws -> R {
    try await withTestFileSystem { fileSystem, filePath, originalTimestamp in
        let provider = try await FileProvider<TestSnapshot>(
            parsingOptions: .default,
            filePath: filePath,
            allowMissing: false,
            fileSystem: fileSystem
        )
        return try await body(provider, fileSystem, filePath, originalTimestamp)
    }
}

struct FileProviderTests {
    @available(Configuration 1.0, *)
    @Test func testLoad() async throws {
        try await withTestProvider { provider, fileSystem, filePath, originalTimestamp in
            // Check initial values
            let result1 = try provider.value(forKey: ["key1"], type: .string)
            #expect(try result1.value?.content.asString == "value1")
        }
    }

    @available(Configuration 1.0, *)
    @Test func missingFileMissingError() async throws {
        let fileSystem = InMemoryFileSystem(files: [:])
        let error = await #expect(throws: FileSystemError.self) {
            _ = try await FileProvider<TestSnapshot>(
                parsingOptions: .default,
                filePath: "/etc/config.txt",
                allowMissing: false,
                fileSystem: fileSystem
            )
        }
        guard case .fileNotFound(let filePath) = error else {
            Issue.record("Incorrect error thrown: \(error)")
            return
        }
        #expect(filePath == "/etc/config.txt")
    }

    @available(Configuration 1.0, *)
    @Test func missingFileAllowMissing() async throws {
        let fileSystem = InMemoryFileSystem(files: [:])
        _ = try await FileProvider<TestSnapshot>(
            parsingOptions: .default,
            filePath: "/etc/config.txt",
            allowMissing: true,
            fileSystem: fileSystem
        )
    }

    @available(Configuration 1.0, *)
    @Test func configSuccess() async throws {
        // Test initialization using config reader
        let envProvider = InMemoryProvider(values: [
            "filePath": "/test/config.txt"
        ])
        let config = ConfigReader(provider: envProvider)

        try await withTestFileSystem { fileSystem, filePath, _ in
            let fileProvider = try await FileProvider<TestSnapshot>(
                config: config,
                fileSystem: fileSystem
            )
            #expect(fileProvider.providerName == "FileProvider<TestSnapshot>")
            #expect(fileProvider.description == "TestSnapshot")
        }
    }
}
