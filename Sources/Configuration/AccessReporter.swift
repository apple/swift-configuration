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

// #if canImport(FoundationEssentials)
// public import FoundationEssentials
// #else
public import Foundation
// #endif
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
    public struct Metadata: Sendable {

        /// The source code location where the configuration access occurred.
        public struct SourceLocation: Sendable, CustomStringConvertible {

            /// The identifier of the source file where the access occurred.
            public var fileID: String

            /// The line number within the source file where the access occurred.
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
        @frozen public enum AccessKind: String, Sendable {

            /// A synchronous get operation that returns the current value.
            case get

            /// An asynchronous fetch operation that retrieves the latest value.
            case fetch

            /// An asynchronous watch operation that monitors value changes.
            ///
            /// A separate event is generated for each value update received
            /// from the async sequence.
            case watch
        }

        /// The type of configuration access operation for this event.
        public var accessKind: AccessKind

        /// The configuration key accessed.
        public var key: AbsoluteConfigKey

        /// The expected type of the configuration value.
        public var valueType: ConfigType

        /// The source code location where the access occurred.
        public var sourceLocation: SourceLocation

        /// The timestamp when the configuration access occurred.
        public var accessTimestamp: Date

        /// Creates access event metadata.
        /// - Parameters:
        ///   - accessKind: The type of configuration access operation.
        ///   - key: The configuration key accessed.
        ///   - valueType: The expected type of the configuration value.
        ///   - sourceLocation: The source code location where the access occurred.
        ///   - accessTimestamp: The timestamp when the access occurred.
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
    public struct ProviderResult: Sendable {

        /// The name of the configuration provider that processed the lookup.
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

    /// The results from each configuration provider that was queried.
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

// MARK: - Built-in access reporters

/// An access reporter that forwards events to multiple other reporters.
///
/// Use this reporter to send configuration access events to multiple destinations
/// simultaneously. Each upstream reporter receives a copy of every event in the
/// order they were provided during initialization.
@available(Configuration 1.0, *)
public struct BroadcastingAccessReporter: Sendable {

    /// The reporters that receive forwarded events.
    private let upstreams: [any AccessReporter]

    /// Creates a new broadcasting access reporter.
    ///
    /// - Parameter upstreams: The reporters that will receive forwarded events.
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
