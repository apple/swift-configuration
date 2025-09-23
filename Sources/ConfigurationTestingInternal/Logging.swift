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

public import Logging

extension Logger {
    /// Returns a new Logger that sends logs to the SwiftLogNoOpLogHandler.
    public static var noop: Logger {
        Logger(label: "Noop", factory: { _ in SwiftLogNoOpLogHandler() })
    }

    /// Returns a new Logger that sends logs to standard error and logs at debug level.
    public static var test: Logger {
        var logger = Logger(label: "Test", factory: StreamLogHandler.standardError(label:metadataProvider:))
        logger.logLevel = .debug
        return logger
    }
}
