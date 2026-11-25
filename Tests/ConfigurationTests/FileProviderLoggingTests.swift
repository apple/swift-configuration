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

#if Logging

import Testing
import ConfigurationTestingInternal
@testable import Configuration
import Foundation
import Logging
import SystemPackage

struct FileProviderLoggingTests {

    @available(Configuration 1.0, *)
    @Test func toleratedMissingFileIsLogged() async throws {
        let collectingLogHandler = CollectingLogHandler()
        let logger = Logger(label: "Test", factory: { _ in collectingLogHandler })

        _ = try await FileProvider<TestSnapshot>(
            parsingOptions: .default,
            filePath: "/etc/config.txt",
            allowMissing: true,
            logger: logger,
            fileSystem: InMemoryFileSystem(files: [:])
        )

        let entries = collectingLogHandler.currentEntries
        #expect(entries.count == 1)
        let entry = try #require(entries.first)
        #expect(entry.level == .debug)
        #expect(entry.message == "Initialized file provider from a missing file")
        #expect(entry.metadata["FileProvider<TestSnapshot>.filePath"] == "config.txt")
        #expect(entry.metadata["FileProvider<TestSnapshot>.allowMissing"] == "true")
    }

    @available(Configuration 1.0, *)
    @Test func presentFileLogsNothing() async throws {
        let collectingLogHandler = CollectingLogHandler()
        let logger = Logger(label: "Test", factory: { _ in collectingLogHandler })

        try await withTestFileSystem { fileSystem, filePath, _ in
            _ = try await FileProvider<TestSnapshot>(
                parsingOptions: .default,
                filePath: filePath,
                allowMissing: true,
                logger: logger,
                fileSystem: fileSystem
            )
        }

        #expect(collectingLogHandler.currentEntries.isEmpty)
    }

    @available(Configuration 1.0, *)
    @Test func missingFileNotAllowedThrowsAndLogsNothing() async throws {
        let collectingLogHandler = CollectingLogHandler()
        let logger = Logger(label: "Test", factory: { _ in collectingLogHandler })

        await #expect(throws: (any Error).self) {
            _ = try await FileProvider<TestSnapshot>(
                parsingOptions: .default,
                filePath: "/etc/config.txt",
                allowMissing: false,
                logger: logger,
                fileSystem: InMemoryFileSystem(files: [:])
            )
        }

        #expect(collectingLogHandler.currentEntries.isEmpty)
    }
}

#endif
