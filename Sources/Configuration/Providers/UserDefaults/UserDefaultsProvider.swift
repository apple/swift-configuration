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

#if canImport(Darwin)
package import Foundation

/// A configuration provider that reads values from `UserDefaults`.
///
/// This provider bridges Apple's `UserDefaults` system with the Configuration library,
/// allowing applications to use `UserDefaults` as a configuration source alongside
/// other providers. Values stored in `UserDefaults` are read at query time, so changes
/// made to `UserDefaults` by other parts of the application are reflected immediately.
///
/// ## Use cases
///
/// The `UserDefaults` provider is particularly useful for:
/// - **Application preferences**: Reading user-configurable settings
/// - **Platform integration**: Bridging with Settings bundles on iOS or Preferences on macOS
/// - **Shared configuration**: Reading values from app groups using suite names
///
/// ## Key encoding
///
/// Configuration key components are joined with dots to form UserDefaults keys.
/// For example, the configuration key `["database", "host"]` maps to the
/// UserDefaults key `"database.host"`.
///
/// ## Type handling
///
/// The provider reads values from UserDefaults and converts them to the requested
/// ``ConfigType``. UserDefaults natively supports strings, integers, doubles, and
/// booleans. If a stored value cannot be converted to the requested type, a
/// ``ConfigError/configValueNotConvertible(name:type:)`` error is thrown.
///
/// ## Usage
///
/// ```swift
/// // Read from standard UserDefaults
/// let provider = UserDefaultsProvider()
///
/// // Read from a specific suite (e.g., app group)
/// let sharedProvider = UserDefaultsProvider(
///     suiteName: "group.com.example.app"
/// )
///
/// let config = ConfigReader(provider: provider)
/// let timeout = config.double(forKey: "http.timeout", default: 30.0)
/// ```
@available(Configuration 1.0, *)
public struct UserDefaultsProvider: Sendable {

    /// The underlying snapshot of the internal state of the provider.
    struct Snapshot: @unchecked Sendable {
        /// The name of this instance of the provider.
        let name: String?

        /// The provider name.
        let providerName: String

        /// The UserDefaults instance to read from.
        let defaults: UserDefaults

        /// The secrets specifier.
        let secretsSpecifier: SecretsSpecifier<String, String>

        /// Create a new snapshot.
        /// - Parameters:
        ///   - name: The name of this instance of the provider.
        ///   - defaults: The UserDefaults instance to read from.
        ///   - secretsSpecifier: The secrets specifier.
        init(
            name: String?,
            defaults: UserDefaults,
            secretsSpecifier: SecretsSpecifier<String, String>
        ) {
            self.name = name
            self.defaults = defaults
            self.secretsSpecifier = secretsSpecifier
            self.providerName = "UserDefaultsProvider[\(name ?? "")]"
        }

        /// Encode an absolute config key into a UserDefaults key string.
        func encodeKey(_ key: AbsoluteConfigKey) -> String {
            key.components.joined(separator: ".")
        }

        /// Convert a UserDefaults value to a ConfigValue for the requested type.
        func convert(
            _ rawValue: Any,
            encodedKey: String,
            type: ConfigType
        ) throws -> ConfigValue {
            let isSecret = secretsSpecifier.isSecret(key: encodedKey, value: "\(rawValue)")
            let content: ConfigContent
            switch type {
            case .string:
                guard let stringValue = rawValue as? String else {
                    throw ConfigError.configValueNotConvertible(name: encodedKey, type: type)
                }
                content = .string(stringValue)
            case .int:
                guard let intValue = rawValue as? Int else {
                    throw ConfigError.configValueNotConvertible(name: encodedKey, type: type)
                }
                content = .int(intValue)
            case .double:
                guard let doubleValue = rawValue as? Double else {
                    throw ConfigError.configValueNotConvertible(name: encodedKey, type: type)
                }
                content = .double(doubleValue)
            case .bool:
                guard let boolValue = rawValue as? Bool else {
                    throw ConfigError.configValueNotConvertible(name: encodedKey, type: type)
                }
                content = .bool(boolValue)
            case .bytes:
                if let data = rawValue as? Data {
                    content = .bytes(Array(data))
                } else if let bytes = rawValue as? [UInt8] {
                    content = .bytes(bytes)
                } else {
                    throw ConfigError.configValueNotConvertible(name: encodedKey, type: type)
                }
            case .stringArray:
                guard let array = rawValue as? [String] else {
                    throw ConfigError.configValueNotConvertible(name: encodedKey, type: type)
                }
                content = .stringArray(array)
            case .intArray:
                guard let array = rawValue as? [Int] else {
                    throw ConfigError.configValueNotConvertible(name: encodedKey, type: type)
                }
                content = .intArray(array)
            case .doubleArray:
                guard let array = rawValue as? [Double] else {
                    throw ConfigError.configValueNotConvertible(name: encodedKey, type: type)
                }
                content = .doubleArray(array)
            case .boolArray:
                guard let array = rawValue as? [Bool] else {
                    throw ConfigError.configValueNotConvertible(name: encodedKey, type: type)
                }
                content = .boolArray(array)
            case .byteChunkArray:
                if let dataArray = rawValue as? [Data] {
                    content = .byteChunkArray(dataArray.map { Array($0) })
                } else if let bytesArray = rawValue as? [[UInt8]] {
                    content = .byteChunkArray(bytesArray)
                } else {
                    throw ConfigError.configValueNotConvertible(name: encodedKey, type: type)
                }
            }
            return ConfigValue(content, isSecret: isSecret)
        }
    }

    /// The underlying snapshot of the internal state.
    private let _snapshot: Snapshot

    /// Creates a new UserDefaults provider that reads from the standard UserDefaults.
    ///
    /// - Parameters:
    ///   - name: An optional name for the provider, used in debugging and logging.
    ///   - secretsSpecifier: Specifies which keys or values should be marked as secrets.
    public init(
        name: String? = nil,
        secretsSpecifier: SecretsSpecifier<String, String> = .none
    ) {
        self._snapshot = .init(
            name: name,
            defaults: .standard,
            secretsSpecifier: secretsSpecifier
        )
    }

    /// Creates a new UserDefaults provider that reads from a specific suite.
    ///
    /// Use this initializer to read from shared UserDefaults suites, such as
    /// app group containers.
    ///
    /// - Parameters:
    ///   - name: An optional name for the provider, used in debugging and logging.
    ///   - suiteName: The domain identifier of the search list.
    ///   - secretsSpecifier: Specifies which keys or values should be marked as secrets.
    public init(
        name: String? = nil,
        suiteName: String,
        secretsSpecifier: SecretsSpecifier<String, String> = .none
    ) {
        self._snapshot = .init(
            name: name,
            defaults: UserDefaults(suiteName: suiteName) ?? .standard,
            secretsSpecifier: secretsSpecifier
        )
    }

    /// Creates a new UserDefaults provider that reads from a specific UserDefaults instance.
    ///
    /// This initializer is available within the package for testing purposes.
    /// External users should use the ``init(name:secretsSpecifier:)`` or
    /// ``init(name:suiteName:secretsSpecifier:)`` initializers.
    ///
    /// - Parameters:
    ///   - name: An optional name for the provider, used in debugging and logging.
    ///   - defaults: The UserDefaults instance to read from.
    ///   - secretsSpecifier: Specifies which keys or values should be marked as secrets.
    package init(
        name: String? = nil,
        defaults: UserDefaults,
        secretsSpecifier: SecretsSpecifier<String, String> = .none
    ) {
        self._snapshot = .init(
            name: name,
            defaults: defaults,
            secretsSpecifier: secretsSpecifier
        )
    }
}

@available(Configuration 1.0, *)
extension UserDefaultsProvider: CustomStringConvertible {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public var description: String {
        "UserDefaultsProvider[\(_snapshot.name.map { "\($0)" } ?? "")]"
    }
}

@available(Configuration 1.0, *)
extension UserDefaultsProvider.Snapshot: ConfigSnapshot {
    func value(
        forKey key: AbsoluteConfigKey,
        type: ConfigType
    ) throws -> LookupResult {
        let encodedKey = encodeKey(key)
        return try withConfigValueLookup(encodedKey: encodedKey) {
            guard let rawValue = defaults.object(forKey: encodedKey) else {
                return nil
            }
            return try convert(rawValue, encodedKey: encodedKey, type: type)
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
        updatesHandler: (_ updates: ConfigUpdatesAsyncSequence<any ConfigSnapshot, Never>) async throws -> Return
    ) async throws -> Return {
        try await watchSnapshotFromSnapshot(updatesHandler: updatesHandler)
    }
}
#endif
