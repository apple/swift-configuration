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

/// A configuration key decoder that splits string keys using a separator character.
///
/// This decoder transforms flat string keys into hierarchical ``ConfigKey`` instances
/// by splitting on a specified separator character. It's commonly used with configuration
/// sources that use dot notation, colon notation, or other delimiter-based key formats.
///
/// ## Usage
///
/// Create a decoder with a custom separator:
///
/// ```swift
/// let decoder = SeparatorKeyDecoder(separator: ".")
/// let key = decoder.decode("database.host.port", context: context)
/// // Results in ConfigKey with components ["database", "host", "port"]
/// ```
///
/// Or use one of the predefined separators:
///
/// ```swift
/// let dotDecoder = ConfigKeyDecoder.dotSeparated
/// let colonDecoder = ConfigKeyDecoder.colonSeparated
/// ```
@available(Configuration 1.0, *)
public struct SeparatorKeyDecoder: Sendable {

    /// The string used to separate key components.
    ///
    /// This separator is used to split flat string keys into hierarchical components.
    /// Common separators include "." for dot notation and ":" for colon notation.
    public var separator: String

    /// Creates a new separator-based key decoder.
    ///
    /// ```swift
    /// let decoder = SeparatorKeyDecoder(separator: "_")
    /// let key = decoder.decode("app_config_debug", context: context)
    /// // Results in ConfigKey with components ["app", "config", "debug"]
    /// ```
    ///
    /// - Parameter separator: The string to use for splitting keys into components.
    public init(separator: String) {
        self.separator = separator
    }
}

@available(Configuration 1.0, *)
extension SeparatorKeyDecoder: ConfigKeyDecoder {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public func decode(_ string: String, context: [String: ConfigContextValue]) -> ConfigKey {
        ConfigKey(string.split(separator: separator).map(String.init), context: context)
    }
}

@available(Configuration 1.0, *)
extension ConfigKeyDecoder where Self == SeparatorKeyDecoder {
    /// A decoder that uses dot notation for hierarchical keys.
    ///
    /// This decoder splits keys using "." as the separator, making it suitable for
    /// configuration sources that use dot notation like `database.host.port`.
    ///
    /// ```swift
    /// let decoder = ConfigKeyDecoder.dotSeparated
    /// let key = decoder.decode("app.database.host", context: context)
    /// // Results in ConfigKey with components ["app", "database", "host"]
    /// ```
    public static var dotSeparated: Self {
        SeparatorKeyDecoder(separator: ".")
    }

    /// A decoder that uses colon notation for hierarchical keys.
    ///
    /// This decoder splits keys using ":" as the separator, making it suitable for
    /// configuration sources that use colon notation like `server:port:number`.
    ///
    /// ```swift
    /// let decoder = ConfigKeyDecoder.colonSeparated
    /// let key = decoder.decode("app:database:host", context: context)
    /// // Results in ConfigKey with components ["app", "database", "host"]
    /// ```
    public static var colonSeparated: Self {
        SeparatorKeyDecoder(separator: ":")
    }
}
