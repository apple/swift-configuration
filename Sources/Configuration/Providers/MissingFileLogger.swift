//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftConfiguration open source project
//
// Copyright (c) 2026 Apple Inc. and the SwiftConfiguration project authors
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
#endif

/// Logs optional missing configuration sources when logging support is enabled.
@available(Configuration 1.0, *)
internal struct MissingFileLogger: Sendable {
    #if Logging
    /// The underlying SwiftLog logger.
    private let logger: Logger

    /// Creates a logger with the specified label.
    init(label: String) {
        self.logger = Logger(label: label)
    }

    /// Creates a logger backed by an existing SwiftLog logger.
    init(logger: Logger) {
        self.logger = logger
    }
    #else
    /// Creates a no-op logger when logging support is disabled.
    init(label: String) {}
    #endif

    /// Records that an optional configuration source was missing.
    func warning(_ message: String, pathKey: String, path: String) {
        #if Logging
        logger.warning(
            .init(stringLiteral: message),
            metadata: [pathKey: .string(path)]
        )
        #endif
    }
}
