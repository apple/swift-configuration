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

#if canImport(Foundation)
import Foundation

/// A configuration provider that reads values from `UserDefaults`.
///
/// This provider reads configuration values from a `UserDefaults` instance,
/// supporting both flat key lookups and nested dictionary lookups (useful for
/// MDM managed configurations).
///
/// ## Key transformation
///
/// This provider transforms configuration keys into dot-separated strings.
/// For example, a key with components `["http", "timeout"]` becomes `"http.timeout"`.
///
/// ## Supported data types
///
/// The provider supports all standard configuration types by reading raw values
/// from `UserDefaults` and performing type conversion:
/// - Strings, integers, doubles, and booleans
/// - Arrays of strings, integers, doubles, and booleans
/// - Byte arrays (base64-encoded strings by default)
///
/// ## Lookup modes
///
/// The provider supports two lookup strategies:
///
/// - **Flat mode** (default): Reads values directly from `UserDefaults` using
///   the dot-separated key. For example, `config.string(forKey: "http.timeout")`
///   reads `UserDefaults.standard.object(forKey: "http.timeout")`.
///
/// - **Nested mode**: Reads a dictionary from a specific `UserDefaults` key, then
///   looks up the configuration key within that dictionary. This is useful for
///   MDM managed configurations stored under `"com.apple.configuration.managed"`.
///
/// ## Usage
///
/// ### Flat mode (default)
///
/// ```swift
/// // Assuming UserDefaults contains:
/// // "http.timeout" = 30
/// // "app.name" = "MyApp"
///
/// let provider = UserDefaultsProvider()
/// let config = ConfigReader(provider: provider)
/// let timeout = config.int(forKey: "http.timeout", default: 60)
/// ```
///
/// ### Nested mode (MDM configurations)
///
/// ```swift
/// // Assuming UserDefaults contains a dictionary at "com.apple.configuration.managed":
/// // { "http.timeout": 30, "app.name": "MyApp" }
///
/// let provider = UserDefaultsProvider.nested(
///     dictionaryKey: "com.apple.configuration.managed"
/// )
/// let config = ConfigReader(provider: provider)
/// let timeout = config.int(forKey: "http.timeout", default: 60)
/// ```
///
/// ### Config context
///
/// The UserDefaults provider ignores the context passed in ``AbsoluteConfigKey/context``.
@available(Configuration 1.0, *)
public struct UserDefaultsProvider: Sendable {

    /// The lookup strategy for reading values from UserDefaults.
    enum LookupMode: Sendable {
        /// Reads values directly from UserDefaults using the encoded key.
        case flat

        /// Reads a dictionary from UserDefaults at the specified key,
        /// then looks up the configuration key within that dictionary.
        case nested(dictionaryKey: String)
    }

    /// The snapshot of the internal state of the provider.
    struct Snapshot: @unchecked Sendable {
        /// The name of the provider.
        let providerName: String

        /// The UserDefaults instance to read from.
        let defaults: UserDefaults

        /// The lookup mode.
        let lookupMode: LookupMode

        /// A decoder of bytes from a string.
        var bytesDecoder: any ConfigBytesFromStringDecoder

        /// A decoder of bool values from a string or number.
        static func decodeBool(from value: Any) -> Bool? {
            if let boolValue = value as? Bool {
                return boolValue
            }
            if let intValue = value as? Int {
                return intValue != 0
            }
            if let stringValue = value as? String {
                let lowercased = stringValue.lowercased()
                return switch lowercased {
                case "yes", "1", "true": true
                case "no", "0", "false": false
                default: nil
                }
            }
            return nil
        }
    }

    /// The key encoder that uses dot-separated notation.
    static let keyEncoder: SeparatorKeyEncoder = .dotSeparated

    /// The underlying snapshot of the provider.
    private let _snapshot: Snapshot

    /// Creates a new provider that reads flat keys from the specified `UserDefaults`.
    ///
    /// In flat mode, configuration keys are looked up directly in `UserDefaults`.
    /// For example, `config.string(forKey: "http.timeout")` reads
    /// `defaults.object(forKey: "http.timeout")`.
    ///
    /// ```swift
    /// // Read from standard UserDefaults
    /// let provider = UserDefaultsProvider()
    ///
    /// // Read from a custom suite (e.g., app groups)
    /// let provider = UserDefaultsProvider(
    ///     defaults: UserDefaults(suiteName: "group.com.myapp")!
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - defaults: The `UserDefaults` instance to read from. Defaults to `.standard`.
    ///   - bytesDecoder: The decoder used for converting string values to byte arrays.
    public init(
        defaults: UserDefaults = .standard,
        bytesDecoder: some ConfigBytesFromStringDecoder = .base64
    ) {
        self._snapshot = Snapshot(
            providerName: "UserDefaultsProvider[flat]",
            defaults: defaults,
            lookupMode: .flat,
            bytesDecoder: bytesDecoder
        )
    }

    /// Creates a new provider that reads values from a dictionary stored in `UserDefaults`.
    ///
    /// In nested mode, the provider first reads a dictionary from `UserDefaults` at the
    /// specified `dictionaryKey`, then looks up configuration keys within that dictionary.
    /// This is particularly useful for reading MDM managed configurations.
    ///
    /// ```swift
    /// // Read MDM managed configuration
    /// let provider = UserDefaultsProvider.nested(
    ///     dictionaryKey: "com.apple.configuration.managed"
    /// )
    ///
    /// // Read from a custom suite with a nested dictionary
    /// let provider = UserDefaultsProvider.nested(
    ///     dictionaryKey: "app.settings",
    ///     defaults: UserDefaults(suiteName: "group.com.myapp")!
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - dictionaryKey: The key in `UserDefaults` that contains the configuration dictionary.
    ///   - defaults: The `UserDefaults` instance to read from. Defaults to `.standard`.
    ///   - bytesDecoder: The decoder used for converting string values to byte arrays.
    /// - Returns: A new provider configured for nested lookup.
    public static func nested(
        dictionaryKey: String,
        defaults: UserDefaults = .standard,
        bytesDecoder: some ConfigBytesFromStringDecoder = .base64
    ) -> UserDefaultsProvider {
        UserDefaultsProvider(
            snapshot: Snapshot(
                providerName: "UserDefaultsProvider[nested: \(dictionaryKey)]",
                defaults: defaults,
                lookupMode: .nested(dictionaryKey: dictionaryKey),
                bytesDecoder: bytesDecoder
            )
        )
    }

    /// Internal initializer for creating a provider from a snapshot.
    private init(snapshot: Snapshot) {
        self._snapshot = snapshot
    }
}

@available(Configuration 1.0, *)
extension UserDefaultsProvider: CustomStringConvertible {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public var description: String {
        _snapshot.providerName
    }
}

@available(Configuration 1.0, *)
extension UserDefaultsProvider: CustomDebugStringConvertible {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public var debugDescription: String {
        _snapshot.providerName
    }
}

@available(Configuration 1.0, *)
extension UserDefaultsProvider.Snapshot {

    /// Resolves the raw value for the given encoded key from UserDefaults.
    /// - Parameter encodedKey: The dot-separated key string.
    /// - Returns: The raw value from UserDefaults, or nil if not found.
    func rawValue(forEncodedKey encodedKey: String) -> Any? {
        switch lookupMode {
        case .flat:
            return defaults.object(forKey: encodedKey)
        case .nested(let dictionaryKey):
            guard let dictionary = defaults.dictionary(forKey: dictionaryKey) else {
                return nil
            }
            return dictionary[encodedKey]
        }
    }

    /// Parses a config value from a raw UserDefaults value.
    /// - Parameters:
    ///   - rawValue: The raw value from UserDefaults.
    ///   - name: The name of the config value (for error reporting).
    ///   - type: The requested config type.
    /// - Returns: The parsed config value.
    /// - Throws: If the value cannot be converted to the requested type.
    func parseValue(
        rawValue: Any,
        name: String,
        type: ConfigType
    ) throws -> ConfigValue {
        func throwMismatch() throws -> Never {
            throw ConfigError.configValueNotConvertible(name: name, type: type)
        }
        let content: ConfigContent
        switch type {
        case .string:
            if let stringValue = rawValue as? String {
                content = .string(stringValue)
            } else {
                content = .string("\(rawValue)")
            }
        case .int:
            if let intValue = rawValue as? Int {
                content = .int(intValue)
            } else if let stringValue = rawValue as? String, let intValue = Int(stringValue) {
                content = .int(intValue)
            } else {
                try throwMismatch()
            }
        case .double:
            if let doubleValue = rawValue as? Double {
                content = .double(doubleValue)
            } else if let intValue = rawValue as? Int {
                content = .double(Double(intValue))
            } else if let stringValue = rawValue as? String, let doubleValue = Double(stringValue) {
                content = .double(doubleValue)
            } else {
                try throwMismatch()
            }
        case .bool:
            guard let boolValue = Self.decodeBool(from: rawValue) else {
                try throwMismatch()
            }
            content = .bool(boolValue)
        case .bytes:
            if let stringValue = rawValue as? String, let decoded = bytesDecoder.decode(stringValue) {
                content = .bytes(decoded)
            } else {
                try throwMismatch()
            }
        case .stringArray:
            if let arrayValue = rawValue as? [String] {
                content = .stringArray(arrayValue)
            } else {
                try throwMismatch()
            }
        case .intArray:
            if let arrayValue = rawValue as? [Int] {
                content = .intArray(arrayValue)
            } else {
                try throwMismatch()
            }
        case .doubleArray:
            if let arrayValue = rawValue as? [Double] {
                content = .doubleArray(arrayValue)
            } else {
                try throwMismatch()
            }
        case .boolArray:
            if let arrayValue = rawValue as? [Bool] {
                content = .boolArray(arrayValue)
            } else {
                try throwMismatch()
            }
        case .byteChunkArray:
            if let arrayValue = rawValue as? [String] {
                let chunks = try arrayValue.map { stringValue in
                    guard let decoded = bytesDecoder.decode(stringValue) else {
                        try throwMismatch()
                    }
                    return decoded
                }
                content = .byteChunkArray(chunks)
            } else {
                try throwMismatch()
            }
        }
        return .init(content, isSecret: false)
    }
}

@available(Configuration 1.0, *)
extension UserDefaultsProvider.Snapshot: ConfigSnapshot {
    func value(
        forKey key: AbsoluteConfigKey,
        type: ConfigType
    ) throws -> LookupResult {
        let encodedKey = UserDefaultsProvider.keyEncoder.encode(key)
        return try withConfigValueLookup(encodedKey: encodedKey) { () -> ConfigValue? in
            guard let raw = rawValue(forEncodedKey: encodedKey) else {
                return nil
            }
            return try parseValue(rawValue: raw, name: encodedKey, type: type)
        }
    }
}

@available(Configuration 1.0, *)
extension UserDefaultsProvider: ConfigProvider {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public var providerName: String {
        _snapshot.providerName
    }

    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public func value(
        forKey key: AbsoluteConfigKey,
        type: ConfigType
    ) throws -> LookupResult {
        try _snapshot.value(forKey: key, type: type)
    }

    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public func fetchValue(
        forKey key: AbsoluteConfigKey,
        type: ConfigType
    ) async throws -> LookupResult {
        try value(forKey: key, type: type)
    }

    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public func watchValue<Return: ~Copyable>(
        forKey key: AbsoluteConfigKey,
        type: ConfigType,
        updatesHandler: (
            _ updates: ConfigUpdatesAsyncSequence<Result<LookupResult, any Error>, Never>
        ) async throws -> Return
    ) async throws -> Return {
        try await watchValueFromValue(forKey: key, type: type, updatesHandler: updatesHandler)
    }

    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public func snapshot() -> any ConfigSnapshot {
        _snapshot
    }

    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public func watchSnapshot<Return: ~Copyable>(
        updatesHandler: (
            _ updates: ConfigUpdatesAsyncSequence<any ConfigSnapshot, Never>
        ) async throws -> Return
    ) async throws -> Return {
        try await watchSnapshotFromSnapshot(updatesHandler: updatesHandler)
    }
}
#endif
