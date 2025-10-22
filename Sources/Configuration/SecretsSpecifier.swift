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

/// A specification for identifying which configuration values contain sensitive information.
///
/// Configuration providers use secrets specifiers to determine which values should be
/// marked as sensitive and protected from accidental disclosure in logs, debug output,
/// or access reports. Secret values are handled specially by ``AccessReporter`` instances
/// and other components that process configuration data.
///
/// ## Usage patterns
///
/// ### Mark all values as secret
///
/// Use this for providers that exclusively handle sensitive data:
///
/// ```swift
/// let provider = InMemoryProvider(
///     values: ["api.key": "secret123", "db.password": "pass456"],
///     secretsSpecifier: .all
/// )
/// ```
///
/// ### Mark specific keys as secret
///
/// Use this when you know which specific keys contain sensitive information:
///
/// ```swift
/// let provider = EnvironmentVariablesProvider(
///     secretsSpecifier: .specific(
///         ["API_KEY", "DATABASE_PASSWORD", "JWT_SECRET"]
///     )
/// )
/// ```
///
/// ### Dynamic secret detection
///
/// Use this for complex logic that determines secrecy based on key patterns or values:
///
/// ```swift
/// let provider = FileProvider<JSONSnapshot>(
///     filePath: "/etc/config.json",
///     secretsSpecifier: .dynamic { key, value in
///         // Mark keys containing "password",
///         // "secret", or "token" as secret
///         key.lowercased().contains("password") ||
///         key.lowercased().contains("secret") ||
///         key.lowercased().contains("token")
///     }
/// )
/// ```
///
/// ### No secret values
///
/// Use this for providers that handle only non-sensitive configuration:
///
/// ```swift
/// let provider = InMemoryProvider(
///     values: ["app.name": "MyApp", "log.level": "info"],
///     secretsSpecifier: .none
/// )
/// ```
public enum SecretsSpecifier<KeyType: Sendable & Hashable, ValueType: Sendable>: Sendable {

    /// The library treats all configuration values as secrets.
    ///
    /// Use this case when the provider exclusively handles sensitive information
    /// and all values should be protected from disclosure.
    case all

    /// The library treats no configuration values as secrets.
    ///
    /// Use this case when the provider handles only non-sensitive configuration
    /// data that can be safely logged or displayed.
    case none

    /// The library treats the specified keys as secrets.
    ///
    /// Use this case when you have a known set of keys that contain sensitive
    /// information. All other keys will be treated as non-secret.
    ///
    /// - Parameter keys: The set of keys that should be treated as secrets.
    case specific(Set<KeyType>)

    /// The library determines the secret status dynamically by evaluating each key-value pair.
    ///
    /// Use this case when you need complex logic to determine whether a value
    /// is secret based on the key name, value content, or other criteria.
    ///
    /// - Parameter closure: A closure that takes a key and value and returns
    ///   whether the value should be treated as secret.
    case dynamic(@Sendable (KeyType, ValueType) -> Bool)
}

extension SecretsSpecifier {
    /// Determines whether a configuration value should be treated as secret.
    ///
    /// This method evaluates the secrets specifier against the provided key-value
    /// pair to determine if the value contains sensitive information that should
    /// be protected from disclosure.
    ///
    /// ```swift
    /// let specifier: SecretsSpecifier<String, String> = .specific(["API_KEY"])
    /// let isSecret = specifier.isSecret(key: "API_KEY", value: "secret123")
    /// // Returns: true
    /// ```
    ///
    /// - Parameters:
    ///   - key: The provider-specific configuration key.
    ///   - value: The configuration value to evaluate.
    /// - Returns: `true` if the value should be treated as secret; otherwise, `false`.
    public func isSecret(key: KeyType, value: ValueType) -> Bool {
        let isSecret: Bool
        switch self {
        case .all:
            isSecret = true
        case .none:
            isSecret = false
        case .specific(let set):
            isSecret = set.contains(key)
        case .dynamic(let isSecretClosure):
            isSecret = isSecretClosure(key, value)
        }
        return isSecret
    }
}
