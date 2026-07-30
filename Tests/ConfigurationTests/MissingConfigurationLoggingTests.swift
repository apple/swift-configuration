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
@testable import Configuration
import Logging
import SystemPackage
import ConfigurationTestingInternal

@Suite(.serialized)
struct MissingConfigurationLoggingTests {
    @available(Configuration 1.0, *)
    @Test func fileProviderLogsWhenAllowMissing() async throws {
        // CollectingLogHandler keeps messages when handler.logLevel >= message.level,
        // while Logger emits when logger.logLevel <= message.level. Both share this
        // value, so .notice is required for notice-level diagnostics to be recorded.
        var collectingLogHandler = CollectingLogHandler()
        collectingLogHandler.logLevel = .notice
        let logger = Logger(label: "Test", factory: { _ in collectingLogHandler })
        try await MissingConfigurationLogging.withOverrideLogger(logger) {
            let fileSystem = InMemoryFileSystem(files: [:])
            _ = try await FileProvider<TestSnapshot>(
                parsingOptions: .default,
                filePath: "/etc/config.txt",
                allowMissing: true,
                fileSystem: fileSystem
            )
        }

        let entries = collectingLogHandler.currentEntries
        #expect(entries.count == 1)
        #expect(entries[0].level == .notice)
        #expect(entries[0].message.contains("allowMissing"))
        #expect(entries[0].metadata["path"] == "/etc/config.txt")
        #expect(entries[0].metadata["provider"] == "FileProvider<TestSnapshot>")
    }

    @available(Configuration 1.0, *)
    @Test func environmentFileLogsWhenAllowMissing() async throws {
        var collectingLogHandler = CollectingLogHandler()
        collectingLogHandler.logLevel = .notice
        let logger = Logger(label: "Test", factory: { _ in collectingLogHandler })
        try await MissingConfigurationLogging.withOverrideLogger(logger) {
            let fileSystem = InMemoryFileSystem(files: [:])
            _ = try await EnvironmentVariablesProvider(
                environmentFilePath: "/missing/.env",
                allowMissing: true,
                fileSystem: fileSystem
            )
        }

        let entries = collectingLogHandler.currentEntries
        #expect(entries.count == 1)
        #expect(entries[0].level == .notice)
        #expect(entries[0].metadata["path"] == "/missing/.env")
        #expect(entries[0].metadata["provider"] == "EnvironmentVariablesProvider")
    }

    @available(Configuration 1.0, *)
    @Test func directoryProviderLogsWhenAllowMissing() async throws {
        var collectingLogHandler = CollectingLogHandler()
        collectingLogHandler.logLevel = .notice
        let logger = Logger(label: "Test", factory: { _ in collectingLogHandler })
        try await MissingConfigurationLogging.withOverrideLogger(logger) {
            let fileSystem = InMemoryFileSystem(files: [:])
            _ = try await DirectoryFilesProvider(
                directoryPath: "/missing/secrets",
                allowMissing: true,
                fileSystem: fileSystem
            )
        }

        let entries = collectingLogHandler.currentEntries
        #expect(entries.count == 1)
        #expect(entries[0].level == .notice)
        #expect(entries[0].metadata["path"] == "/missing/secrets")
        #expect(entries[0].metadata["provider"] == "DirectoryFilesProvider")
    }
}

#endif
