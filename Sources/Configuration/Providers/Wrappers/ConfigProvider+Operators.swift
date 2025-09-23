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

    /// Creates a new prefixed configuration provider with a string prefix.
    ///
    /// This convenience method allows you to specify a string prefix that will be
    /// decoded using the provided key decoder.
    ///
    /// - Parameters:
    ///   - prefix: The string prefix to decode and prepend to all configuration keys.
    ///   - context: Additional context used when decoding the prefix string.
    ///   - keyDecoder: The decoder to use for parsing the prefix string.
    /// - Returns: A provider which prefixes keys.
    public func prefixKeys(
        with prefix: String,
        context: [String: ConfigContextValue] = [:],
        keyDecoder: some ConfigKeyDecoder = .dotSeparated
    ) -> KeyMappingProvider<Self> {
        self.prefixKeys(with: keyDecoder.decode(prefix, context: context))
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
}
