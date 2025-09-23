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

/// A protocol for decoding string representations into structured configuration keys.
///
/// Key decoders transform flat string keys (like those found in environment variables
/// or configuration files) into hierarchical ``ConfigKey`` instances. This allows
/// configuration providers to work with different key naming conventions while
/// maintaining a consistent internal representation.
///
/// ## Usage
///
/// Implement this protocol to create custom key decoding strategies:
///
/// ```swift
/// struct CustomKeyDecoder: ConfigKeyDecoder {
///     func decode(_ string: String, context: [String: ConfigContextValue]) -> ConfigKey {
///         let components = string.split(separator: "__").map(String.init)
///         return ConfigKey(components: components, context: context)
///     }
/// }
/// ```
///
/// ## Common implementations
///
/// The framework provides several built-in key decoders:
/// - ``SeparatorKeyDecoder`` - Splits keys using a separator character
///
/// ## See also
///
/// - ``ConfigKeyEncoder`` - For encoding keys back to strings
/// - ``ConfigKey`` - The structured key representation
public protocol ConfigKeyDecoder: Sendable {

    /// Decodes a string representation into a structured configuration key.
    ///
    /// This method transforms a flat string key into a hierarchical ``ConfigKey``
    /// by parsing the string according to the decoder's specific strategy. The context
    /// provides additional information that may influence the decoding process.
    ///
    /// ```swift
    /// let decoder = SeparatorKeyDecoder(separator: ".")
    /// let key = decoder.decode("database.host", context: context)
    /// // Results in ConfigKey with components ["database", "host"]
    /// ```
    ///
    /// - Parameters:
    ///   - string: The string representation to decode into a configuration key.
    ///   - context: Additional configuration context that may influence decoding.
    /// - Returns: A structured configuration key representing the decoded string.
    func decode(_ string: String, context: [String: ConfigContextValue]) -> ConfigKey
}
