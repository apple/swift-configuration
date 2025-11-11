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
/// sources that use dot notation.
@available(Configuration 1.0, *)
package struct DotSeparatorKeyDecoder {
    /// Decodes a string representation into a structured configuration key.
    /// - Parameters:
    ///   - string: The string representation to decode into a configuration key.
    ///   - context: Additional configuration context that may influence decoding.
    /// - Returns: A structured configuration key representing the decoded string.
    package static func decode(_ string: String, context: [String: ConfigContextValue]) -> ConfigKey {
        ConfigKey(string.split(separator: ".").map(String.init), context: context)
    }
}
