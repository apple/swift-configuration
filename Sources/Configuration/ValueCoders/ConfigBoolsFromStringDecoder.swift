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

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// A decoder that converts a boolean string into a Bool, taking into account different boolean string pairs.
///
/// This decoder is able to convert a string to Bool values when the string’s Boolean value format is 0 or 1, true or false, or yes or no.
///
/// ## Boolean values
///
/// Following boolean string pairs are decoded to a Bool value: trueFalse (true, false), oneZero (1, 0), yesNo (yes, no).
/// Decoding is case-insensitive.
@available(Configuration 1.0, *)
public struct BoolDecoder: Sendable {

    /// Creates a new bool decoder.
    public init() {}

    public func decodeBool(from string: String) -> Bool? {
        let stringLowercased = string.lowercased()
        return if ["true", "false"].contains(stringLowercased) {
            stringLowercased == "true"
        } else if ["yes", "no"].contains(stringLowercased) {
            stringLowercased == "yes"
        } else if ["1", "0"].contains(stringLowercased) {
            stringLowercased == "1"
        } else {
            nil
        }
    }
}
