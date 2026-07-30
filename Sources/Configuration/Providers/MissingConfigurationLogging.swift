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

import Logging
import SystemPackage
import Synchronization

/// Helpers for logging when an optional configuration file or directory is missing.
///
/// These messages are only emitted when the `Logging` package trait is enabled,
/// matching the dependency of ``AccessLogger`` and reloading providers.
@available(Configuration 1.0, *)
enum MissingConfigurationLogging {
    /// Optional logger override used by unit tests.
    private static let overrideLogger: Mutex<Logger?> = .init(nil)

    /// Runs `body` while routing missing-config logs to `logger`.
    /// - Parameters:
    ///   - logger: The logger that should receive missing-config notices.
    ///   - body: The work to perform while the override is active.
    static func withOverrideLogger(
        _ logger: Logger,
        _ body: () async throws -> Void
    ) async rethrows {
        overrideLogger.withLock { $0 = logger }
        defer { overrideLogger.withLock { $0 = nil } }
        try await body()
    }

    /// Logs that a configuration file was missing and treated as empty.
    /// - Parameters:
    ///   - providerName: The configuration provider name for diagnostics.
    ///   - path: The missing file path.
    static func logMissingFile(
        providerName: String,
        path: FilePath
    ) {
        let resolved =
            overrideLogger.withLock { $0 }
            ?? Logger(label: "Configuration.\(providerName)")
        resolved.notice(
            "Configuration file not found; treating as empty because allowMissing is true",
            metadata: [
                "provider": .string(providerName),
                "path": .string(path.string),
            ]
        )
    }

    /// Logs that a configuration directory was missing and treated as empty.
    /// - Parameters:
    ///   - providerName: The configuration provider name for diagnostics.
    ///   - path: The missing directory path.
    static func logMissingDirectory(
        providerName: String,
        path: FilePath
    ) {
        let resolved =
            overrideLogger.withLock { $0 }
            ?? Logger(label: "Configuration.\(providerName)")
        resolved.notice(
            "Configuration directory not found; treating as empty because allowMissing is true",
            metadata: [
                "provider": .string(providerName),
                "path": .string(path.string),
            ]
        )
    }
}

#endif
