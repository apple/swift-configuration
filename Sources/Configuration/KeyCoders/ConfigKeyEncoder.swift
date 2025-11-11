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

/// A protocol for encoding structured configuration keys into string representations.
///
/// Key encoders transform hierarchical ``AbsoluteConfigKey`` instances into flat
/// string keys suitable for use with external configuration sources like environment
/// variables or configuration files. This allows configuration providers to work with
/// different key naming conventions while maintaining a consistent internal representation.
///
/// ## Usage
///
/// Implement this protocol to create custom key encoding strategies:
///
/// ```swift
/// struct CustomKeyEncoder: ConfigKeyEncoder {
///     func encode(_ key: AbsoluteConfigKey) -> String {
///         return key.components.joined(separator: "__")
///     }
/// }
/// ```
///
/// ## Common implementations
///
/// The framework provides several built-in key encoders:
/// - ``SeparatorKeyEncoder`` - Joins key components using a separator character
///
/// ## See also
///
/// - ``AbsoluteConfigKey`` - The structured key representation
@available(Configuration 1.0, *)
public protocol ConfigKeyEncoder: Sendable {

    /// Encodes a structured configuration key into its string representation.
    ///
    /// This method transforms a hierarchical ``AbsoluteConfigKey`` into a flat string
    /// according to the encoder's specific strategy. The resulting string is suitable
    /// for use with external configuration sources.
    ///
    /// ```swift
    /// let encoder = SeparatorKeyEncoder(separator: ".")
    /// let key = AbsoluteConfigKey(components: ["database", "host"], context: context)
    /// let encoded = encoder.encode(key)
    /// // Results in "database.host"
    /// ```
    ///
    /// - Parameter key: The structured configuration key to encode.
    /// - Returns: A string representation of the configuration key.
    func encode(_ key: AbsoluteConfigKey) -> String
}
