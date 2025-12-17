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

import Testing
import Foundation
@testable import Configuration

struct ConfigBoolsFromStringDecoderTests {

    @Test()
    @available(Configuration 1.0, *)
    func stringToBool() throws {
        let bd = BoolDecoder()
        let cases: [(expected: Bool?, input: [String])] = [
            (true, ["1"]),
            (false, ["0"]),
            (true, ["Yes", "yes", "YES", "yES"]),
            (false, ["No", "no", "NO", "nO"]),
            (true, ["true", "TRUE", "trUe"]),
            (false, ["false", "FALSE", "faLse"]),
            (nil, ["", "_true_", "_false_", "_yes_", "_no_", "_1_", "_0_", "11", "00"])
        ]

        for (expected, inputs) in cases {
            for input in inputs {
                #expect(bd.decodeBool(from: input) == expected, "input: \(input)")
            }
        }
    }
}
