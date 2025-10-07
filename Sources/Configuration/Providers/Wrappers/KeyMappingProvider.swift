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

/// A configuration provider that maps all keys before delegating to an upstream provider.
///
/// Use `KeyMappingProvider` to automatically apply a mapping function to every configuration key
/// before passing it to an underlying provider. This is particularly useful when the upstream
/// source of configuration keys differs from your own. Another example is namespacing configuration
/// values from specific sources, such as prefixing environment variables with an application name
/// while leaving other configuration sources unchanged.
///
/// ### Common use cases
///
/// Use `KeyMappingProvider` for:
/// - Rewriting configuration keys to match upstream configuration sources.
/// - Legacy system integration that adapts existing sources with different naming conventions.
///
/// ## Example
///
/// Use `KeyMappingProvider` when you want to map keys for specific providers in a multi-provider
/// setup:
///
/// ```swift
/// // Create providers
/// let envProvider = EnvironmentVariablesProvider()
/// let jsonProvider = try await JSONProvider(filePath: "/etc/config.json")
///
/// // Only remap the environment variables, not the JSON config
/// let keyMappedEnvProvider = KeyMappingProvider(upstream: envProvider) { key in
///     key.prepending(["myapp", "prod"])
/// }
///
/// let config = ConfigReader(providers: [
///     keyMappedEnvProvider, // Reads from "MYAPP_PROD_*" environment variables
///     jsonProvider          // Reads from JSON without prefix
/// ])
///
/// // This reads from "MYAPP_PROD_DATABASE_HOST" env var or "database.host" in JSON
/// let host = config.string(forKey: "database.host", default: "localhost")
/// ```
///
/// ## Convenience method
///
/// You can also use the ``ConfigProvider/prefixKeys(with:)`` convenience method on
/// configuration provider types to wrap one in a ``KeyMappingProvider``:
///
/// ```swift
/// let envProvider = EnvironmentVariablesProvider()
/// let keyMappedEnvProvider = envProvider.mapKeys { key in
///     key.prepending(["myapp", "prod"])
/// }
/// ```
@available(Configuration 1.0, *)
public struct KeyMappingProvider<Upstream: ConfigProvider>: Sendable {
    /// The mapping function applied to each key before a lookup.
    private let mapKey: @Sendable (AbsoluteConfigKey) -> AbsoluteConfigKey

    /// The upstream configuration provider to delegate to after mapping keys.
    private let upstream: Upstream

    /// Creates a new provider.
    ///
    /// - Parameters:
    ///   - upstream: The upstream provider to delegate to after mapping.
    ///   - mapKey: A closure to remap configuration keys.
    public init(
        upstream: Upstream,
        keyMapper mapKey: @Sendable @escaping (_ key: AbsoluteConfigKey) -> AbsoluteConfigKey
    ) {
        self.mapKey = mapKey
        self.upstream = upstream
    }
}

@available(Configuration 1.0, *)
extension KeyMappingProvider: ConfigProvider {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public var providerName: String {
        "KeyMappingProvider[upstream: \(upstream.providerName)]"
    }

    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public func value(forKey key: AbsoluteConfigKey, type: ConfigType) throws -> LookupResult {
        try upstream.value(forKey: self.mapKey(key), type: type)
    }

    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public func fetchValue(forKey key: AbsoluteConfigKey, type: ConfigType) async throws -> LookupResult {
        try await upstream.fetchValue(forKey: self.mapKey(key), type: type)
    }

    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public func watchValue<Return>(
        forKey key: AbsoluteConfigKey,
        type: ConfigType,
        updatesHandler: (
            ConfigUpdatesAsyncSequence<Result<LookupResult, any Error>, Never>
        ) async throws -> Return
    ) async throws -> Return {
        try await upstream.watchValue(forKey: self.mapKey(key), type: type, updatesHandler: updatesHandler)
    }

    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public func snapshot() -> any ConfigSnapshotProtocol {
        MappedKeySnapshot(mapKey: self.mapKey, upstream: self.upstream.snapshot())
    }

    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public func watchSnapshot<Return>(
        updatesHandler: (ConfigUpdatesAsyncSequence<any ConfigSnapshotProtocol, Never>) async throws -> Return
    ) async throws -> Return {
        try await upstream.watchSnapshot { sequence in
            try await updatesHandler(
                ConfigUpdatesAsyncSequence(
                    sequence
                        .map { snapshot in
                            MappedKeySnapshot(mapKey: self.mapKey, upstream: self.upstream.snapshot())
                        }
                )
            )
        }
    }
}

/// A configuration snapshot that maps all keys before delegating to an upstream snapshot.
@available(Configuration 1.0, *)
private struct MappedKeySnapshot: ConfigSnapshotProtocol {

    /// The prefix key to prepend to all configuration keys.
    let mapKey: @Sendable (AbsoluteConfigKey) -> AbsoluteConfigKey

    /// The upstream configuration snapshot to delegate to after prefixing keys.
    var upstream: any ConfigSnapshotProtocol

    var providerName: String {
        "KeyMappingProvider[upstream: \(self.upstream.providerName)]"
    }

    func value(forKey key: AbsoluteConfigKey, type: ConfigType) throws -> LookupResult {
        try upstream.value(forKey: self.mapKey(key), type: type)
    }
}

@available(Configuration 1.0, *)
extension KeyMappingProvider: CustomStringConvertible {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public var description: String {
        "KeyMappingProvider[upstream: \(self.upstream)]"
    }
}

@available(Configuration 1.0, *)
extension KeyMappingProvider: CustomDebugStringConvertible {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public var debugDescription: String {
        let upstreamDebug = String(reflecting: self.upstream)
        return "KeyMappingProvider[upstream: \(upstreamDebug)]"
    }
}
