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
/// Boolean strings taken into account when decoding are configurable at init time only.
///
/// ## Boolean values
///
/// By default, following boolean string pairs are decoded to a Bool value: trueFalse (true, false), oneZero (1, 0), yesNo (yes, no).
/// Decoding is case-insensitive.
@available(Configuration 1.0, *)
public struct BoolDecoder: Sendable {

    public enum BooleanString: Sendable { case trueFalse, oneZero, yesNo }

    public static var allBooleanStrings: Self { .init(booleanStrings: [.trueFalse, .oneZero, .yesNo]) }

    private let booleanStrings: [BooleanString]

    public init(booleanStrings: [BooleanString]) {
        self.booleanStrings = booleanStrings
    }

    func decodeBool(from string: String) -> Bool? {
        for semantic in self.booleanStrings {
            switch semantic {
            case .trueFalse:
                let stringLowercased = string.lowercased()
                if ["true", "false"].contains(stringLowercased) {
                    return stringLowercased == "true"
                }
            case .oneZero:
                if ["1", "0"].contains(string) {
                    return string == "1"
                }
            case .yesNo:
                let stringLowercased = string.lowercased()
                if ["yes", "no"].contains(stringLowercased) {
                    return stringLowercased == "yes"
                }
            }
        }
        return nil
    }
}
