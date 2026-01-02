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

public import Logging

import Synchronization

/// An access reporter that logs configuration access events using the Swift Log API.
///
/// This reporter integrates with the Swift Log library to provide structured
/// logging of configuration accesses. Each configuration access generates a
/// log entry with detailed metadata about the operation, making it easy to track
/// configuration usage and debug issues.
///
/// ## Package traits
///
/// This type is guarded by the `Logging` package trait.
///
/// ## Usage
///
/// Create an access logger and pass it to your configuration reader:
///
/// ```swift
/// import Logging
///
/// let logger = Logger(label: "config.access")
/// let accessLogger = AccessLogger(logger: logger, level: .info)
/// let config = ConfigReader(
///     provider: EnvironmentVariablesProvider(),
///     accessReporter: accessLogger
/// )
/// ```
///
/// ## Log format
///
/// Each access event generates a structured log entry with metadata including:
/// - `kind`: The type of access operation (get, fetch, watch).
/// - `key`: The configuration key accessed.
/// - `location`: The source code location of the access.
/// - `value`: The resolved configuration value (redacted for secrets).
/// - `counter`: An incrementing counter for tracking access frequency.
/// - Provider-specific information for each provider in the hierarchy.
@available(Configuration 1.0, *)
public final class AccessLogger: Sendable {

    /// The logger used to emit configuration access events.
    private let logger: Logger

    /// The log level at which configuration access events are emitted.
    private let level: Logger.Level

    /// The static message text associated with each log entry.
    private let message: Logger.Message

    /// A counter that tracks the number of access events processed.
    private let counter: Mutex<Int> = .init(0)

    /// Creates a new access logger that reports configuration access events.
    ///
    /// ```swift
    /// let logger = Logger(label: "my.app.config")
    ///
    /// // Log at debug level by default
    /// let accessLogger = AccessLogger(logger: logger)
    ///
    /// // Customize the log level
    /// let accessLogger = AccessLogger(logger: logger, level: .info)
    /// ```
    ///
    /// - Parameters:
    ///   - logger: The logger to emit access events to.
    ///   - level: The log level for access events. Defaults to `.debug`.
    ///   - message: The static message text for log entries. Defaults to "Config value accessed".
    public init(
        logger: Logger,
        level: Logger.Level = .debug,
        message: Logger.Message = "Config value accessed"
    ) {
        self.logger = logger
        self.level = level
        self.message = message
    }
}

@available(Configuration 1.0, *)
extension AccessLogger: AccessReporter {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public func report(_ event: AccessEvent) {
        var metadata: Logger.Metadata = [:]
        metadata.reserveCapacity(10)
        event.addMetadata(&metadata)
        let number = counter.withLock {
            $0 += 1
            return $0
        }
        metadata["counter"] = .stringConvertible(number)
        logger.log(level: level, message, metadata: metadata)
    }
}

@available(Configuration 1.0, *)
extension AccessEvent.Metadata {
    /// Add log metadata.
    /// - Parameter metadata: The metadata to which to add values.
    func addMetadata(_ metadata: inout Logger.Metadata) {
        metadata["kind"] = .string(accessKind.rawValue)
        metadata["key"] = .string(key.description)
        metadata["location"] = .string(sourceLocation.description)
    }
}

@available(Configuration 1.0, *)
extension AccessEvent.ProviderResult {
    /// Add log metadata.
    /// - Parameters:
    ///   - metadata: The metadata to which to add values.
    ///   - number: The number of the provider to include in the metadata key.
    func addMetadata(_ metadata: inout Logger.Metadata, at number: Int) {
        metadata["\(number).providerName"] = .string(providerName)
        switch result {
        case .success(let success):
            metadata["\(number).encodedKey"] = .string(success.encodedKey)
            metadata["\(number).value"] = .string(success.value?.description ?? "<nil>")
        case .failure(let failure):
            metadata["\(number).error"] = "\(failure)"
        }
    }
}

@available(Configuration 1.0, *)
extension AccessEvent {
    /// Add log metadata.
    /// - Parameter metadata: The metadata to which to add values.
    func addMetadata(_ metadata: inout Logger.Metadata) {
        self.metadata.addMetadata(&metadata)
        for (index, providerResult) in self.providerResults.enumerated() {
            providerResult.addMetadata(&metadata, at: index + 1)
        }
        if let conversionError {
            metadata["conversionError"] = "\(conversionError)"
        }
        result.addMetadata(&metadata)
    }
}

@available(Configuration 1.0, *)
extension Result<ConfigValue?, any Error> {
    /// Add log metadata.
    /// - Parameter metadata: The metadata to which to add values.
    func addMetadata(_ metadata: inout Logger.Metadata) {
        switch self {
        case .success(let success):
            metadata["value"] = .string(success?.description ?? "nil")
        case .failure(let failure):
            metadata["error"] = "\(failure)"
        }
    }
}

#endif
