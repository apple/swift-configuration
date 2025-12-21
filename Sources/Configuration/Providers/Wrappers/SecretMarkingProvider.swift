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

/// A configuration provider that marks values as secrets based on key patterns.
///
/// Use `SecretMarkingProvider` to mark configuration values as secrets when the upstream
/// provider doesn't identify sensitive data. This is particularly useful when integrating
/// with external configuration sources or when you want to apply consistent secret handling
/// across providers that use different conventions.
///
/// ### Common use cases
///
/// Use `SecretMarkingProvider` for:
/// - Marking environment variables containing passwords or API keys as secrets.
/// - Adding secret protection to third-party configuration providers.
///
/// ## Example
///
/// Use `SecretMarkingProvider` when you want to mark secrets for specific providers:
///
/// ```swift
/// let envProvider = EnvironmentVariablesProvider()
///
/// let secretMarkedProvider = SecretMarkingProvider(upstream: envProvider) { key in
///     key.description.lowercased().contains("password") ||
///     key.description.lowercased().contains("secret")
/// }
///
/// let config = ConfigReader(provider: secretMarkedProvider)
/// let dbPassword = config.string(forKey: "database.password") // marked as secret
/// ```
///
/// ## Convenience method
///
/// You can also use the ``ConfigProvider/markSecrets(where:)`` convenience method:
///
/// ```swift
/// let provider = EnvironmentVariablesProvider()
///     .markSecrets { $0.description.contains("password") }
/// ```
@available(Configuration 1.0, *)
public struct SecretMarkingProvider<Upstream: ConfigProvider>: Sendable {
    /// The predicate to check if a key's value should be marked as secret.
    private let isSecretKey: @Sendable (AbsoluteConfigKey) -> Bool

    /// The upstream provider.
    private let upstream: Upstream

    /// Creates a new provider that marks values as secrets based on a predicate.
    ///
    /// - Parameters:
    ///   - upstream: The upstream provider to delegate to.
    ///   - isSecretKey: A closure that determines whether values for a given key should be marked as secrets.
    public init(
        upstream: Upstream,
        isSecretKey: @Sendable @escaping (_ key: AbsoluteConfigKey) -> Bool
    ) {
        self.isSecretKey = isSecretKey
        self.upstream = upstream
    }
}

@available(Configuration 1.0, *)
extension SecretMarkingProvider {
    private func markSecretIfNeeded(_ value: ConfigValue?, forKey key: AbsoluteConfigKey) -> ConfigValue? {
        guard var value else { return nil }
        if isSecretKey(key) {
            value = ConfigValue(value.content, isSecret: true)
        }
        return value
    }

    private func markSecretIfNeeded(_ result: LookupResult, forKey key: AbsoluteConfigKey) -> LookupResult {
        LookupResult(
            encodedKey: result.encodedKey,
            value: markSecretIfNeeded(result.value, forKey: key)
        )
    }
}

@available(Configuration 1.0, *)
extension SecretMarkingProvider: ConfigProvider {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public var providerName: String {
        "SecretMarkingProvider[upstream: \(upstream.providerName)]"
    }

    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public func value(forKey key: AbsoluteConfigKey, type: ConfigType) throws -> LookupResult {
        let result = try upstream.value(forKey: key, type: type)
        return markSecretIfNeeded(result, forKey: key)
    }

    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public func fetchValue(forKey key: AbsoluteConfigKey, type: ConfigType) async throws -> LookupResult {
        let result = try await upstream.fetchValue(forKey: key, type: type)
        return markSecretIfNeeded(result, forKey: key)
    }

    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public func watchValue<Return: ~Copyable>(
        forKey key: AbsoluteConfigKey,
        type: ConfigType,
        updatesHandler: (
            _ updates: ConfigUpdatesAsyncSequence<Result<LookupResult, any Error>, Never>
        ) async throws -> Return
    ) async throws -> Return {
        try await upstream.watchValue(forKey: key, type: type) { sequence in
            try await updatesHandler(
                ConfigUpdatesAsyncSequence(
                    sequence
                        .map { result in
                            result.map { lookupResult in
                                self.markSecretIfNeeded(lookupResult, forKey: key)
                            }
                        }
                )
            )
        }
    }

    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public func snapshot() -> any ConfigSnapshot {
        SecretMarkedSnapshot(isSecretKey: self.isSecretKey, upstream: self.upstream.snapshot())
    }

    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public func watchSnapshot<Return: ~Copyable>(
        updatesHandler: (_ updates: ConfigUpdatesAsyncSequence<any ConfigSnapshot, Never>) async throws -> Return
    ) async throws -> Return {
        try await upstream.watchSnapshot { sequence in
            try await updatesHandler(
                ConfigUpdatesAsyncSequence(
                    sequence
                        .map { snapshot in
                            SecretMarkedSnapshot(isSecretKey: self.isSecretKey, upstream: snapshot)
                        }
                )
            )
        }
    }
}

/// A snapshot that marks values as secrets based on key patterns.
@available(Configuration 1.0, *)
private struct SecretMarkedSnapshot: ConfigSnapshot {

    /// The predicate to check if a key's value should be marked as secret.
    let isSecretKey: @Sendable (AbsoluteConfigKey) -> Bool

    /// The upstream snapshot to delegate to.
    var upstream: any ConfigSnapshot

    var providerName: String {
        "SecretMarkingProvider[upstream: \(self.upstream.providerName)]"
    }

    func value(forKey key: AbsoluteConfigKey, type: ConfigType) throws -> LookupResult {
        let result = try upstream.value(forKey: key, type: type)
        guard var value = result.value else {
            return result
        }
        if isSecretKey(key) {
            value = ConfigValue(value.content, isSecret: true)
        }
        return LookupResult(encodedKey: result.encodedKey, value: value)
    }
}

@available(Configuration 1.0, *)
extension SecretMarkingProvider: CustomStringConvertible {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public var description: String {
        "SecretMarkingProvider[upstream: \(self.upstream)]"
    }
}

@available(Configuration 1.0, *)
extension SecretMarkingProvider: CustomDebugStringConvertible {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public var debugDescription: String {
        let upstreamDebug = String(reflecting: self.upstream)
        return "SecretMarkingProvider[upstream: \(upstreamDebug)]"
    }
}

