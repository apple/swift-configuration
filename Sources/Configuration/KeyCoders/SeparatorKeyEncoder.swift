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

/// A configuration key encoder that joins key components using a separator character.
///
/// This encoder transforms hierarchical ``AbsoluteConfigKey`` instances into flat
/// string keys by joining components with a specified separator character. It's commonly
/// used with configuration sources that expect dot notation, dash notation, or other
/// delimiter-based key formats.
///
/// ## Usage
///
/// Create an encoder with a custom separator:
///
/// ```swift
/// let encoder = SeparatorKeyEncoder(separator: ".")
/// let key = AbsoluteConfigKey(components: ["database", "host", "port"], context: context)
/// let encoded = encoder.encode(key)
/// // Results in "database.host.port"
/// ```
///
/// Or use one of the predefined separators:
///
/// ```swift
/// let dotEncoder = ConfigKeyEncoder.dotSeparated
/// let dashEncoder = ConfigKeyEncoder.dashSeparated
/// ```
@available(Configuration 1.0, *)
internal struct SeparatorKeyEncoder {

    /// The string used to join key components.
    ///
    /// This separator is inserted between each component when encoding hierarchical
    /// keys into flat strings. Common separators include "." for dot notation and
    /// "-" for dash notation.
    var separator: String
}

@available(Configuration 1.0, *)
extension SeparatorKeyEncoder: ConfigKeyEncoder {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    func encode(_ key: AbsoluteConfigKey) -> String {
        key.components.joined(separator: separator)
    }
}

@available(Configuration 1.0, *)
extension ConfigKeyEncoder where Self == SeparatorKeyEncoder {
    /// An encoder that uses dot notation for hierarchical keys.
    ///
    /// This encoder joins key components using "." as the separator, making it suitable for
    /// configuration sources that expect dot notation like `database.host.port`.
    ///
    /// ```swift
    /// let encoder = ConfigKeyEncoder.dotSeparated
    /// let key = AbsoluteConfigKey(components: ["app", "database", "host"], context: context)
    /// let encoded = encoder.encode(key)
    /// // Results in "app.database.host"
    /// ```
    static var dotSeparated: Self {
        SeparatorKeyEncoder(separator: ".")
    }

    /// An encoder that uses dash notation for hierarchical keys.
    ///
    /// This encoder joins key components using "-" as the separator, making it suitable for
    /// configuration sources that expect dash notation like `database-host-port`.
    ///
    /// ```swift
    /// let encoder = ConfigKeyEncoder.dashSeparated
    /// let key = AbsoluteConfigKey(components: ["app", "database", "host"], context: context)
    /// let encoded = encoder.encode(key)
    /// // Results in "app-database-host"
    /// ```
    static var dashSeparated: Self {
        SeparatorKeyEncoder(separator: "-")
    }
}
