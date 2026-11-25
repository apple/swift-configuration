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

struct DirectoryFilesProviderLoggingTests {

    @available(Configuration 1.0, *)
    @Test func toleratedMissingDirectoryIsLogged() async throws {
        let collectingLogHandler = CollectingLogHandler()
        let logger = Logger(label: "Test", factory: { _ in collectingLogHandler })

        _ = try await DirectoryFilesProvider(
            directoryPath: "/run/secrets",
            allowMissing: true,
            logger: logger,
            fileSystem: InMemoryFileSystem(files: [:])
        )

        let entries = collectingLogHandler.currentEntries
        #expect(entries.count == 1)
        let entry = try #require(entries.first)
        #expect(entry.level == .debug)
        #expect(entry.message == "Initialized directory files provider from a missing directory")
        #expect(entry.metadata["DirectoryFilesProvider.directoryPath"] == "secrets")
        #expect(entry.metadata["DirectoryFilesProvider.allowMissing"] == "true")
    }

    @available(Configuration 1.0, *)
    @Test func presentDirectoryLogsNothing() async throws {
        let collectingLogHandler = CollectingLogHandler()
        let logger = Logger(label: "Test", factory: { _ in collectingLogHandler })

        _ = try await DirectoryFilesProvider(
            directoryPath: "/run/secrets",
            allowMissing: true,
            logger: logger,
            fileSystem: InMemoryFileSystem(files: [
                "/run/secrets/database-password": .init(
                    lastModifiedTimestamp: Date(),
                    data: .file(Data("secretpass123".utf8))
                )
            ])
        )

        #expect(collectingLogHandler.currentEntries.isEmpty)
    }

    @available(Configuration 1.0, *)
    @Test func missingDirectoryNotAllowedThrowsAndLogsNothing() async throws {
        let collectingLogHandler = CollectingLogHandler()
        let logger = Logger(label: "Test", factory: { _ in collectingLogHandler })

        await #expect(throws: (any Error).self) {
            _ = try await DirectoryFilesProvider(
                directoryPath: "/run/secrets",
                allowMissing: false,
                logger: logger,
                fileSystem: InMemoryFileSystem(files: [:])
            )
        }

        #expect(collectingLogHandler.currentEntries.isEmpty)
    }
}

#endif
