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

#if canImport(FoundationEssentials)
public import FoundationEssentials
#else
public import Foundation
#endif
import Synchronization

/// A type that receives and processes configuration access events.
///
/// Access reporters track when configuration values are read, fetched, or watched,
/// to provide visibility into configuration usage patterns. This is useful for
/// debugging, auditing, and understanding configuration dependencies.
@available(Configuration 1.0, *)
public protocol AccessReporter: Sendable {

    /// Processes a configuration access event.
    ///
    /// This method is called whenever a configuration value is accessed through
    /// a ``ConfigReader`` or a ``ConfigSnapshotReader``. Implementations should handle
    /// events efficiently as they may be called frequently.
    ///
    /// - Parameter event: The configuration access event to process.
    func report(_ event: AccessEvent)
}

/// An event that captures information about accessing a configuration value.
///
/// Access events are generated whenever configuration values are accessed through
/// ``ConfigReader`` and ``ConfigSnapshotReader`` methods. They contain metadata about
/// the access, results from individual providers, and the final outcome of the operation.
@available(Configuration 1.0, *)
public struct AccessEvent: Sendable {

    /// Metadata describing the configuration access operation.
    ///
    /// Contains information about the type of access, the key accessed, value type,
    /// source location, and timestamp.
    public struct Metadata: Sendable {

        /// The source code location where a configuration access occurs.
        ///
        /// Captures the file identifier and line number for debugging and auditing purposes.
        public struct SourceLocation: Sendable, CustomStringConvertible {

            /// The identifier of the source file where the access occurs.
            public var fileID: String

            /// The line number within the source file where the access occurs.
            public var line: UInt

            /// Creates a new source location.
            /// - Parameters:
            ///   - fileID: The identifier of the source file.
            ///   - line: The line number within the source file.
            public init(fileID: String, line: UInt) {
                self.fileID = fileID
                self.line = line
            }

            // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
            public var description: String {
                "\(fileID):\(line)"
            }
        }

        /// The type of configuration access operation.
        ///
        /// Indicates whether the access is a synchronous get, asynchronous fetch,
        /// or an async watch operation.
        @frozen public enum AccessKind: String, Sendable {

            /// A synchronous get operation that returns the current value.
            case get

            /// An asynchronous fetch operation that retrieves the latest value.
            case fetch

            /// An asynchronous watch operation that monitors value changes.
            ///
            /// The async sequence generates a separate event for each value update.
            case watch
        }

        /// The type of configuration access operation for this event.
        public var accessKind: AccessKind

        /// The configuration key accessed.
        public var key: AbsoluteConfigKey

        /// The expected type of the configuration value.
        public var valueType: ConfigType

        /// The source code location where the access occurs.
        public var sourceLocation: SourceLocation

        /// The timestamp when the configuration access occurs.
        public var accessTimestamp: Date

        /// Creates access event metadata.
        /// - Parameters:
        ///   - accessKind: The type of configuration access operation.
        ///   - key: The configuration key accessed.
        ///   - valueType: The expected type of the configuration value.
        ///   - sourceLocation: The source code location where the access occurs.
        ///   - accessTimestamp: The timestamp when the access occurs.
        public init(
            accessKind: AccessKind,
            key: AbsoluteConfigKey,
            valueType: ConfigType,
            sourceLocation: SourceLocation,
            accessTimestamp: Date
        ) {
            self.accessKind = accessKind
            self.key = key
            self.valueType = valueType
            self.sourceLocation = sourceLocation
            self.accessTimestamp = accessTimestamp
        }
    }

    /// The result of a configuration lookup from a specific provider.
    ///
    /// Contains the provider's name and the outcome of querying that provider,
    /// which can be either a successful lookup result or an error.
    public struct ProviderResult: Sendable {

        /// The name of the configuration provider that processes the lookup.
        public var providerName: String

        /// The outcome of the configuration lookup operation.
        public var result: Result<LookupResult, any Error>

        /// Creates a provider result.
        /// - Parameters:
        ///   - providerName: The name of the configuration provider.
        ///   - result: The outcome of the configuration lookup operation.
        public init(
            providerName: String,
            result: Result<LookupResult, any Error>
        ) {
            self.providerName = providerName
            self.result = result
        }
    }

    /// Metadata that describes the configuration access operation.
    public var metadata: Metadata

    /// The results from each configuration provider queried.
    public var providerResults: [ProviderResult]

    /// An error that occurred when converting the raw config value into another type, for example `RawRepresentable`.
    public var conversionError: (any Error)?

    /// The final outcome of the configuration access operation.
    /// - Note: Might contain `success` even if a ``conversionError`` occurred, which non-throwing config reader methods use.
    public var result: Result<ConfigValue?, any Error>

    /// Creates a configuration access event.
    /// - Parameters:
    ///   - metadata: Metadata describing the access operation.
    ///   - providerResults: The results from each provider queried.
    ///   - conversionError: An error that occurred when converting the raw config value into another type, for example `RawRepresentable`.
    ///   - result: The final outcome of the access operation.
    public init(
        metadata: Metadata,
        providerResults: [ProviderResult],
        conversionError: (any Error)? = nil,
        result: Result<ConfigValue?, any Error>
    ) {
        self.metadata = metadata
        self.providerResults = providerResults
        self.conversionError = conversionError
        self.result = result
    }
}

@available(Configuration 1.0, *)
extension AccessEvent: CustomStringConvertible {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public var description: String {
        renderedSummary(dateFormatStyle: .accessEventSummary(timeZone: .gmt))
    }
}

@available(Configuration 1.0, *)
extension Date.ISO8601FormatStyle {
    /// Returns the format style used for rendering timestamps in access event summaries.
    /// - Parameter timeZone: The time zone for timestamp formatting.
    /// - Returns: The format style.
    static func accessEventSummary(timeZone: TimeZone) -> Self {
        var formatStyle = Self.iso8601
            .year().month().day().timeZone(separator: .omitted)
            .time(includingFractionalSeconds: true).timeSeparator(.colon)
        formatStyle.timeZone = timeZone
        return formatStyle
    }
}

@available(Configuration 1.0, *)
extension AccessEvent {
    /// Returns a human-readable single line string summarizing the access event.
    /// - Parameter dateFormatStyle: The format style used for rendering dates.
    /// - Returns: The rendered string.
    func renderedSummary(dateFormatStyle: Date.ISO8601FormatStyle) -> String {
        // Compute which provider actually supplied the final value, might be nil.
        let resolvedProvider = providerResults.first(where: { providerResult in
            switch providerResult.result {
            case .success(let value) where value.value != nil:
                return true
            default:
                return false
            }
        })

        // ✅ foo.bar -> "value" - provided by EnvironmentVariablesProvider
        // 🟡 foo.baz -> "defaultValue" - returned the default
        // 🟡 foo.baz -> nil - no default provided
        // ❌ foo.ban -> "defaultValue" / nil - EnvironmentVariablesProvider threw an error: ...

        let emoji: String
        let valueString: String
        let statusString: String
        switch result {
        case .success(let maybeValue):
            if let maybeValue {
                valueString = maybeValue.isSecret ? "<REDACTED>" : maybeValue.content.renderedDescription
            } else {
                valueString = "<nil>"
            }

            if let resolvedProvider {
                if let conversionError {
                    statusString =
                        "provided by \(resolvedProvider.providerName) but failed to convert: \(conversionError)"
                    emoji = "🟡"
                } else {
                    statusString = "provided by \(resolvedProvider.providerName)"
                    emoji = "✅"
                }
            } else if maybeValue != nil {
                statusString = "all providers returned nil, got the default value"
                emoji = "🟡"
            } else {
                statusString = "all providers returned nil"
                emoji = "🟡"
            }
        case .failure(let error):
            valueString = "<error>"
            statusString = "threw an error: \(error)"
            emoji = "❌"
        }
        let metadataString =
            "\(metadata.accessKind.rawValue.capitalized) \(metadata.valueType) from \(metadata.sourceLocation) at \(metadata.accessTimestamp.formatted(dateFormatStyle))"
        return "\(emoji) \(metadata.key.description) -> \"\(valueString)\" - \(statusString) / \(metadataString)"
    }
}

@available(Configuration 1.0, *)
extension ConfigContent {
    /// Returns a string representation of the config value, formatting complex types appropriately.
    ///
    /// Assumes default encoding for bytes (base64) and arrays (comma-separated).
    var renderedDescription: String {
        // TODO: Make this more correct by taking a bytesValueEncoder and arrayValueEncoder, rather than assuming the default.
        switch self {
        case .string(let string):
            return string
        case .int(let int):
            return "\(int)"
        case .double(let double):
            return "\(double)"
        case .bool(let bool):
            return "\(bool)"
        case .bytes(let bytes):
            return Data(bytes).base64EncodedString()
        case .stringArray(let array):
            return array.joined(separator: ",")
        case .intArray(let array):
            return array.map(\.description).joined(separator: ",")
        case .doubleArray(let array):
            return array.map(\.description).joined(separator: ",")
        case .boolArray(let array):
            return array.map(\.description).joined(separator: ",")
        case .byteChunkArray(let array):
            return array.map { Data($0).base64EncodedString() }.joined(separator: ",")
        }
    }
}

// MARK: - Built-in access reporters

/// An access reporter that forwards events to multiple other reporters.
///
/// Use this reporter to send configuration access events to multiple destinations
/// simultaneously. Each upstream reporter receives a copy of every event in the
/// order you provide during initialization.
///
/// ```swift
/// let fileLogger = try FileAccessLogger(filePath: "/tmp/config.log")
/// let accessLogger = AccessLogger(logger: logger)
/// let broadcaster = BroadcastingAccessReporter(upstreams: [fileLogger, accessLogger])
///
/// let config = ConfigReader(
///     provider: EnvironmentVariablesProvider(),
///     accessReporter: broadcaster
/// )
/// ```
@available(Configuration 1.0, *)
public struct BroadcastingAccessReporter: Sendable {

    /// The reporters that receive forwarded events.
    private let upstreams: [any AccessReporter]

    /// Creates a new broadcasting access reporter.
    ///
    /// - Parameter upstreams: The reporters that will receive forwarded events.
    /// - Precondition: `upstreams` must not be empty.
    public init(upstreams: [any AccessReporter]) {
        precondition(!upstreams.isEmpty, "BroadcastingAccessReporter upstreams cannot be empty")
        self.upstreams = upstreams
    }
}

@available(Configuration 1.0, *)
extension BroadcastingAccessReporter: AccessReporter {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public func report(_ event: AccessEvent) {
        for upstream in upstreams {
            upstream.report(event)
        }
    }
}
