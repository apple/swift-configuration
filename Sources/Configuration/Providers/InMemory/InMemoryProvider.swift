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

/// A configuration provider that stores values in memory.
///
/// This provider maintains a static dictionary of configuration values in memory,
/// making it ideal for providing default values, overrides, or test configurations.
/// Values are immutable once the provider is created and never change over time.
///
/// ## Use cases
///
/// The in-memory provider is particularly useful for:
/// - **Default configurations**: Providing fallback values when other providers don't have a value
/// - **Configuration overrides**: Taking precedence over other providers
/// - **Testing**: Creating predictable configuration states for unit tests
/// - **Static configurations**: Embedding compile-time configuration values
///
/// ## Value types
///
/// The provider supports all standard configuration value types and automatically
/// handles type validation. Values must match the requested type exactly - no
/// automatic conversion is performed - for example, requesting a `String` value for
/// a key that stores an `Int` value will throw an error.
///
/// ## Performance characteristics
///
/// This provider offers O(1) lookup time and performs no I/O operations.
/// All values are stored in memory.
///
/// ## Usage
///
/// ```swift
/// let provider = InMemoryProvider(values: [
///     "http.client.user-agent": "Config/1.0 (Test)",
///     "http.client.timeout": 15.0,
///     "http.secret": ConfigValue("s3cret", isSecret: true),
///     "http.version": 2,
///     "enabled": true
/// ])
/// // Prints all values, redacts "http.secret" automatically.
/// print(provider)
/// let config = ConfigReader(provider: provider)
/// let isEnabled = config.bool(forKey: "enabled", default: false)
/// ```
///
/// To learn more about the in-memory providers, check out <doc:Using-in-memory-providers>.
@available(Configuration 1.0, *)
public struct InMemoryProvider: Sendable {

    /// The underlying snapshot of the internal state of the provider.
    struct Snapshot {
        /// The name of this instance of the provider.
        ///
        /// The assumption is that there might be multiple instances in a given process.
        var name: String?

        /// The provider name.
        var providerName: String {
            "InMemoryProvider[\(name ?? "")]"
        }

        /// The underlying config values.
        var values: [AbsoluteConfigKey: ConfigValue]
    }

    /// The underlying snapshot of the internal state.
    private let _snapshot: Snapshot

    /// Creates a new in-memory provider with the specified configuration values.
    ///
    /// This initializer takes a dictionary of absolute configuration keys mapped to
    /// their values. Use this when you have already constructed ``AbsoluteConfigKey``
    /// instances or when working with keys programmatically.
    ///
    /// ```swift
    /// let key1 = AbsoluteConfigKey(components: ["database", "host"], context: [:])
    /// let key2 = AbsoluteConfigKey(components: ["database", "port"], context: [:])
    ///
    /// let provider = InMemoryProvider(
    ///     name: "database-config",
    ///     values: [
    ///         key1: "localhost",
    ///         key2: 5432
    ///     ]
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - name: An optional name for the provider, used in debugging and logging.
    ///   - values: A dictionary mapping absolute configuration keys to their values.
    public init(
        name: String? = nil,
        values: [AbsoluteConfigKey: ConfigValue]
    ) {
        self._snapshot = .init(name: name, values: values)
    }
}

@available(Configuration 1.0, *)
extension InMemoryProvider: CustomStringConvertible {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public var description: String {
        "InMemoryProvider[\(_snapshot.name.map { "\($0), " } ?? " ")\(_snapshot.values.count) values]"
    }
}

@available(Configuration 1.0, *)
extension InMemoryProvider: CustomDebugStringConvertible {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public var debugDescription: String {
        let prettyValues = _snapshot.values
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: ", ")
        return
            "InMemoryProvider[\(_snapshot.name.map { "\($0), " } ?? " ")\(_snapshot.values.count) values: \(prettyValues)]"
    }
}

@available(Configuration 1.0, *)
extension InMemoryProvider.Snapshot: ConfigSnapshot {
    func value(
        forKey key: AbsoluteConfigKey,
        type: ConfigType
    ) throws -> LookupResult {
        try withConfigValueLookup(encodedKey: key.description) {
            guard let value = values[key] else {
                return nil
            }
            guard value.content.type == type else {
                throw ConfigError.configValueNotConvertible(name: key.description, type: type)
            }
            return value
        }
    }
}

@available(Configuration 1.0, *)
extension InMemoryProvider: ConfigProvider {
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
    public func watchValue<Return>(
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
    public func watchSnapshot<Return>(
        updatesHandler: (_ updates: ConfigUpdatesAsyncSequence<any ConfigSnapshot, Never>) async throws -> Return
    ) async throws -> Return {
        try await watchSnapshotFromSnapshot(updatesHandler: updatesHandler)
    }
}
