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

#if LoggingSupport

package import Logging
import Synchronization

/// A  single logged entry with level, message, and metadata.
@available(Configuration 1.0, *)
package struct Entry: Sendable, Equatable {

    /// The log level.
    package var level: Logger.Level

    /// The log message.
    package var message: String

    /// The log metadata.
    package var metadata: [String: String]

    /// Creates an entry.
    /// - Parameters:
    ///   - level: The log level.
    ///   - message: The log message.
    ///   - metadata: The log metadata.
    package init(level: Logger.Level, message: String, metadata: [String: String]) {
        self.level = level
        self.message = message
        self.metadata = metadata
    }
}

/// A log handler that collects log entries in memory for inspection.
@available(Configuration 1.0, *)
package struct CollectingLogHandler: LogHandler {

    /// The metadata applied to all log messages from this handler.
    package var metadata: Logger.Metadata = [:]

    /// The minimum log level this handler will record.
    package var logLevel: Logger.Level = .debug

    /// Internal storage for collected log entries.
    private let storage: Storage

    /// The underlying storage.
    private final class Storage: Sendable {

        /// The backing store for entries.
        private let entries: Mutex<[Entry]>

        /// Creates a new storage.
        init() {
            self.entries = .init([])
        }

        /// Appends a new log entry to the store.
        /// - Parameters:
        ///   - level: The log level.
        ///   - message: The log message.
        ///   - metadata: The log metadata.
        func append(level: Logger.Level, message: Logger.Message, metadata: Logger.Metadata?) {
            entries.withLock { entries in
                entries.append(
                    Entry(
                        level: level,
                        message: message.description,
                        metadata: metadata?.mapValues { $0.description } ?? [:]
                    )
                )
            }
        }

        /// A snapshot of the current entries.
        var currentEntries: [Entry] {
            entries.withLock { $0 }
        }
    }

    /// Creates a new log handler.
    package init() {
        self.storage = .init()
    }

    /// A snapshot of the current entries.
    package var currentEntries: [Entry] {
        storage.currentEntries
    }

    package func log(
        level: Logger.Level,
        message: Logger.Message,
        metadata: Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        guard self.logLevel >= level else {
            return
        }
        self.storage.append(level: level, message: message, metadata: self.metadata.merging(metadata ?? [:]) { $1 })
    }

    package subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get {
            self.metadata[key]
        }
        set {
            self.metadata[key] = newValue
        }
    }
}

#endif
