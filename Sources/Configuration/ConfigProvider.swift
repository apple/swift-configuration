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

/// A type that provides configuration values from a data source.
///
/// Configuration providers offer three access patterns for retrieving values:
///
/// 1. **Get methods**: Synchronous access to current values.
/// 2. **Fetch methods**: Asynchronous access that retrieves fresh values from remote sources.
/// 3. **Watch methods**: Reactive access that provides an async sequence of value updates.
///
/// ## Individual value access
///
/// Access specific configuration values using these methods:
/// - ``ConfigProvider/value(forKey:type:)`` - Get current value synchronously.
/// - ``ConfigProvider/fetchValue(forKey:type:)`` - Fetch latest value asynchronously.
/// - ``ConfigProvider/watchValue(forKey:type:updatesHandler:)`` - Watch for value changes.
///
/// ## Snapshot access
///
/// Access immutable snapshots of the provider's state:
/// - ``ConfigProvider/snapshot()`` - Get current snapshot.
/// - ``ConfigProvider/watchSnapshot(updatesHandler:)`` - Watch for snapshot changes.
///
/// ## Implementation guidance
///
/// **Simple providers**: Implement only the `get` methods and use these convenience methods
/// for the other access patterns:
/// - ``ConfigProvider/watchValueFromValue(forKey:type:updatesHandler:)``
/// - ``ConfigProvider/watchSnapshotFromSnapshot(updatesHandler:)``
///
/// **Remote providers**: Implement `fetch` methods to retrieve up-to-date values from
/// network sources or external systems.
///
/// **Dynamic providers**: Implement `watch` methods to emit real-time updates from
/// polling, file system monitoring, or other change detection mechanisms.
@available(Configuration 1.0, *)
public protocol ConfigProvider: Sendable {

    /// The human-readable name of the configuration provider.
    ///
    /// Used by ``AccessReporter`` and other diagnostic logging.
    var providerName: String { get }

    /// Returns the current value for the specified configuration key.
    ///
    /// This method provides synchronous access to configuration values and should be
    /// efficient to call repeatedly. The returned value may change between calls if
    /// the underlying data source is mutable.
    ///
    /// - Parameters:
    ///   - key: The configuration key to look up.
    ///   - type: The expected configuration value type.
    /// - Returns: The lookup result containing the value and encoded key, or nil if not found.
    /// - Throws: Provider-specific errors or type conversion errors.
    func value(forKey key: AbsoluteConfigKey, type: ConfigType) throws -> LookupResult

    /// Fetches the current value for the specified configuration key.
    ///
    /// This method provides asynchronous access and should contact the authoritative
    /// data source to retrieve the latest value. Providers may cache the fetched values
    /// to make them available through ``value(forKey:type:)``.
    ///
    /// Use this method when you need to ensure you have the most up-to-date value,
    /// especially for remote or frequently changing data sources.
    ///
    /// - Parameters:
    ///   - key: The configuration key to fetch.
    ///   - type: The expected configuration value type.
    /// - Returns: The lookup result that contains the current value and encoded key.
    /// - Throws: Provider-specific errors, network errors, or type conversion errors.
    func fetchValue(forKey key: AbsoluteConfigKey, type: ConfigType) async throws -> LookupResult

    /// Monitors a configuration key for value changes over time.
    ///
    /// The async sequence provided to the handler should immediately emit the current value
    /// (equivalent to calling ``value(forKey:type:)``), followed by subsequent updates as
    /// they occur.
    ///
    /// The sequence completes gracefully when the current task is canceled, to allow
    /// proper cleanup of resources.
    ///
    /// - Parameters:
    ///   - key: The configuration key to monitor.
    ///   - type: The expected configuration value type.
    ///   - updatesHandler: The closure that processes the async sequence of value updates.
    /// - Throws: Provider-specific errors or errors thrown by the handler closure.
    /// - Returns: The value returned by the closure.
    func watchValue<Return: ~Copyable>(
        forKey key: AbsoluteConfigKey,
        type: ConfigType,
        updatesHandler: (
            _ updates: ConfigUpdatesAsyncSequence<Result<LookupResult, any Error>, Never>
        ) async throws -> Return
    ) async throws -> Return

    /// Returns an immutable snapshot of the provider's current state.
    ///
    /// Snapshots provide consistent access to multiple configuration values by capturing
    /// the provider's state at a specific point in time. This prevents values from changing
    /// between reads, which is useful for reading related configuration keys together.
    ///
    /// Snapshots are designed to be lightweight and can be created frequently without
    /// significant performance impact.
    ///
    /// - Returns: An immutable snapshot that represents the current provider state.
    func snapshot() -> any ConfigSnapshot

    /// Monitors the provider's state for changes by emitting snapshots.
    ///
    /// The async sequence provided to the handler should immediately emit the current
    /// snapshot (equivalent to calling ``snapshot()``), followed by new snapshots
    /// as the provider's state changes.
    ///
    /// The sequence completes gracefully when the current task is canceled.
    ///
    /// - Parameter updatesHandler: The closure that processes the asynchronous sequence of snapshot updates.
    /// - Throws: Provider-specific errors or errors thrown by the handler closure.
    /// - Returns: The value returned by the closure.
    func watchSnapshot<Return: ~Copyable>(
        updatesHandler: (_ updates: ConfigUpdatesAsyncSequence<any ConfigSnapshot, Never>) async throws -> Return
    ) async throws -> Return
}

/// An immutable snapshot of a configuration provider's state.
///
/// Snapshots enable consistent reads of multiple related configuration keys by
/// capturing the provider's state at a specific moment. This prevents the underlying
/// data from changing between individual key lookups.
@available(Configuration 1.0, *)
public protocol ConfigSnapshot: Sendable {

    /// The human-readable name of the configuration provider that created this snapshot.
    ///
    /// Used by ``AccessReporter`` and when diagnostic logging the config reader types.
    var providerName: String { get }

    /// Returns a value for the specified key from this immutable snapshot.
    ///
    /// Unlike ``ConfigProvider/value(forKey:type:)``, this method always returns the same
    /// value for identical parameters because the snapshot represents a fixed point in time.
    /// Values can be accessed synchronously and efficiently.
    ///
    /// - Parameters:
    ///   - key: The configuration key to look up.
    ///   - type: The expected configuration value type.
    /// - Returns: The lookup result containing the value and encoded key, or nil if not found.
    /// - Throws: Provider-specific errors or type conversion errors.
    func value(forKey key: AbsoluteConfigKey, type: ConfigType) throws -> LookupResult
}

/// The result of looking up a configuration value in a provider.
@available(Configuration 1.0, *)
public struct LookupResult: Sendable, Equatable, Hashable {

    /// The provider-specific encoding of the configuration key.
    ///
    /// This string shows how the provider interpreted and encoded the key for its
    /// data source, which is useful for debugging configuration lookups.
    public var encodedKey: String

    /// The configuration value found for the key, or nil if not found.
    public var value: ConfigValue?

    /// Creates a lookup result.
    /// - Parameters:
    ///   - encodedKey: The provider-specific encoding of the configuration key.
    ///   - value: The configuration value, or nil if not found.
    public init(encodedKey: String, value: ConfigValue?) {
        self.encodedKey = encodedKey
        self.value = value
    }
}

/// The supported configuration value types.
@available(Configuration 1.0, *)
@frozen public enum ConfigType: String, Sendable, Equatable, Hashable {

    /// A string value.
    case string

    /// An integer value.
    case int

    /// A double value.
    case double

    /// A Boolean value.
    case bool

    /// An array of bytes.
    case bytes

    /// An array of string values.
    case stringArray

    /// An array of integer values.
    case intArray

    /// An array of double values.
    case doubleArray

    /// An array of Boolean values.
    case boolArray

    /// An array of byte chunks.
    case byteChunkArray
}

/// The raw content of a configuration value.
@available(Configuration 1.0, *)
@frozen public enum ConfigContent: Sendable, Equatable, Hashable {

    /// A string value.
    case string(String)

    /// An integer value.
    case int(Int)

    /// A double value.
    case double(Double)

    /// A Boolean value.
    case bool(Bool)

    /// An array of bytes.
    case bytes([UInt8])

    /// An array of string values.
    case stringArray([String])

    /// An array of integer values.
    case intArray([Int])

    /// An array of double values.
    case doubleArray([Double])

    /// An array of Boolean value.
    case boolArray([Bool])

    /// An array of byte arrays.
    case byteChunkArray([[UInt8]])

    /// The configuration type of this content.
    package var type: ConfigType {
        switch self {
        case .string:
            return .string
        case .int:
            return .int
        case .double:
            return .double
        case .bool:
            return .bool
        case .bytes:
            return .bytes
        case .stringArray:
            return .stringArray
        case .intArray:
            return .intArray
        case .doubleArray:
            return .doubleArray
        case .boolArray:
            return .boolArray
        case .byteChunkArray:
            return .byteChunkArray
        }
    }

    /// A string description of the underlying value without type information.
    var underlyingValueDescription: String {
        switch self {
        case .string(let value):
            return value.description
        case .int(let value):
            return value.description
        case .double(let value):
            return value.description
        case .bool(let value):
            return value.description
        case .bytes(let value):
            // Show the first 32 bytes as hexadecimal.
            let hex = value.prefix(32)
                .map {
                    let hexString = String($0, radix: 16)
                    return hexString.count == 1 ? "0" + hexString : hexString
                }
                .joined()
            return "\(value.count) bytes, prefix: \(hex)"
        case .stringArray(let values):
            return values.map(\.description).joined(separator: ", ")
        case .intArray(let values):
            return values.map(\.description).joined(separator: ", ")
        case .doubleArray(let values):
            return values.map(\.description).joined(separator: ", ")
        case .boolArray(let values):
            return values.map(\.description).joined(separator: ", ")
        case .byteChunkArray(let values):
            let descriptions = values.map { value in
                // Show the first 32 bytes as hexadecimal.
                let hex = value.prefix(32)
                    .map {
                        let hexString = String($0, radix: 16)
                        return hexString.count == 1 ? "0" + hexString : hexString
                    }
                    .joined()
                let count = value.count
                return "\(count) bytes, prefix: \(hex)"
            }
            return descriptions.joined(separator: ", ")
        }
    }

    /// An error thrown when the actual type doesn't match the requested type.
    internal struct UnwrapError: Error {

        /// The actual type of the configuration value.
        var actualType: ConfigType

        /// The type that was requested.
        var requestedType: ConfigType
    }

    /// Returns the string value, or throws an error if the content is not a string.
    var asString: String {
        get throws {
            guard case .string(let value) = self else {
                throw UnwrapError(actualType: type, requestedType: .string)
            }
            return value
        }
    }

    /// Returns the integer value, or throws an error if the content is not an integer.
    var asInt: Int {
        get throws {
            guard case .int(let value) = self else {
                throw UnwrapError(actualType: type, requestedType: .int)
            }
            return value
        }
    }

    /// Returns the double value, or throws an error if the content is not a double.
    var asDouble: Double {
        get throws {
            guard case .double(let value) = self else {
                throw UnwrapError(actualType: type, requestedType: .double)
            }
            return value
        }
    }

    /// Returns the Boolean value, or throws an error if the content is not a Boolean.
    var asBool: Bool {
        get throws {
            guard case .bool(let value) = self else {
                throw UnwrapError(actualType: type, requestedType: .bool)
            }
            return value
        }
    }

    /// Returns the byte array, or throws an error if the content is not a byte array.
    var asBytes: [UInt8] {
        get throws {
            guard case .bytes(let value) = self else {
                throw UnwrapError(actualType: type, requestedType: .bytes)
            }
            return value
        }
    }

    /// Returns the array of strings, or throws an error if the content is not an array of strings.
    var asStringArray: [String] {
        get throws {
            guard case .stringArray(let value) = self else {
                throw UnwrapError(actualType: type, requestedType: .stringArray)
            }
            return value
        }
    }

    /// Returns the array of integers, or throws an error if the content is not an array of integers.
    var asIntArray: [Int] {
        get throws {
            guard case .intArray(let value) = self else {
                throw UnwrapError(actualType: type, requestedType: .intArray)
            }
            return value
        }
    }

    /// Returns the array of doubles, or throws an error if the content is not an array of doubles.
    var asDoubleArray: [Double] {
        get throws {
            guard case .doubleArray(let value) = self else {
                throw UnwrapError(actualType: type, requestedType: .doubleArray)
            }
            return value
        }
    }

    /// Returns the array of Booleans, or throws an error if the content is not an array of Booleans.
    var asBoolArray: [Bool] {
        get throws {
            guard case .boolArray(let value) = self else {
                throw UnwrapError(actualType: type, requestedType: .boolArray)
            }
            return value
        }
    }

    /// Returns the array of byte arrays, or throws an error if the content is not an array of byte arrays.
    var asByteChunkArray: [[UInt8]] {
        get throws {
            guard case .byteChunkArray(let value) = self else {
                throw UnwrapError(actualType: type, requestedType: .byteChunkArray)
            }
            return value
        }
    }
}

/// A configuration value that wraps content with metadata.
///
/// Configuration values include the actual content and a flag indicating whether
/// the value contains sensitive information. Secret values are protected from
/// accidental disclosure in logs and debug output.
@available(Configuration 1.0, *)
public struct ConfigValue: Sendable, Equatable, Hashable {

    /// The configuration content.
    public var content: ConfigContent

    /// Whether this value contains sensitive information that should not be logged.
    public var isSecret: Bool

    /// Creates a new configuration value.
    /// - Parameters:
    ///   - content: The configuration content.
    ///   - isSecret: Whether the value contains sensitive information.
    public init(_ content: ConfigContent, isSecret: Bool) {
        self.content = content
        self.isSecret = isSecret
    }
}

@available(Configuration 1.0, *)
extension ConfigValue: CustomStringConvertible {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public var description: String {
        let type = content.type
        if isSecret {
            return "[\(type): <REDACTED>]"
        }
        return "[\(type): \(content.underlyingValueDescription)]"
    }
}

@available(Configuration 1.0, *)
extension ConfigValue: ExpressibleByStringLiteral {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public init(stringLiteral value: String) {
        self = .init(.string(value), isSecret: false)
    }
}

@available(Configuration 1.0, *)
extension ConfigContent: ExpressibleByStringLiteral {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

@available(Configuration 1.0, *)
extension ConfigValue: ExpressibleByIntegerLiteral {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public init(integerLiteral value: Int) {
        self = .init(.int(value), isSecret: false)
    }
}

@available(Configuration 1.0, *)
extension ConfigContent: ExpressibleByIntegerLiteral {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public init(integerLiteral value: Int) {
        self = .int(value)
    }
}

@available(Configuration 1.0, *)
extension ConfigValue: ExpressibleByFloatLiteral {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public init(floatLiteral value: Double) {
        self = .init(.double(value), isSecret: false)
    }
}

@available(Configuration 1.0, *)
extension ConfigContent: ExpressibleByFloatLiteral {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public init(floatLiteral value: Double) {
        self = .double(value)
    }
}

@available(Configuration 1.0, *)
extension ConfigValue: ExpressibleByBooleanLiteral {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public init(booleanLiteral value: Bool) {
        self = .init(.bool(value), isSecret: false)
    }
}

@available(Configuration 1.0, *)
extension ConfigContent: ExpressibleByBooleanLiteral {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}
