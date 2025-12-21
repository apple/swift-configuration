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

@available(Configuration 1.0, *)
extension ConfigProvider {
    /// Creates a new prefixed configuration provider.
    ///
    /// - Parameter: prefix: The configuration key to prepend to all configuration keys.
    /// - Returns: A provider which prefixes keys with the given prefix.
    public func prefixKeys(with prefix: ConfigKey) -> KeyMappingProvider<Self> {
        KeyMappingProvider(upstream: self) { key in
            key.prepending(prefix)
        }
    }

    /// Creates a new configuration provider where each key is rewritten by the given closure.
    ///
    /// - Parameter transform: The closure applied to each key before a lookup.
    /// - Returns: A provider which maps keys using the provided transformation function.
    public func mapKeys(
        _ transform: @Sendable @escaping (_ key: AbsoluteConfigKey) -> AbsoluteConfigKey
    ) -> KeyMappingProvider<Self> {
        KeyMappingProvider(upstream: self, keyMapper: transform)
    }

    /// Creates a provider that marks values as secrets based on the given predicate.
    ///
    /// - Parameter isSecretKey: A closure that returns `true` for keys whose values should be secrets.
    /// - Returns: A provider that marks matching values as secrets.
    public func markSecrets(
        where isSecretKey: @Sendable @escaping (_ key: AbsoluteConfigKey) -> Bool
    ) -> SecretMarkingProvider<Self> {
        SecretMarkingProvider(upstream: self, isSecretKey: isSecretKey)
    }

    /// Creates a provider that marks values as secrets for the specified keys.
    ///
    /// - Parameter keys: Keys whose values should be marked as secrets.
    /// - Returns: A provider that marks the specified keys' values as secrets.
    public func markSecretsForKeys(_ keys: Set<AbsoluteConfigKey>) -> SecretMarkingProvider<Self> {
        SecretMarkingProvider(upstream: self) { keys.contains($0) }
    }
}
