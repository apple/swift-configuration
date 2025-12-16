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

    @available(Configuration 1.0, *)
    @Test("boolDecoder, all boolean strings enabled")
    func boolDecoderAllBooleanStringsEnabled() throws {
        let bd = BoolDecoder(booleanStrings: [.oneZero, .trueFalse, .yesNo])
        #expect(bd.decodeBool(from: "1") == true)
        #expect(bd.decodeBool(from: "0") == false)
        #expect(["Yes", "yes", "YES", "yES"].allSatisfy { bd.decodeBool(from: $0) == true })
        #expect(["No", "no", "NO", "nO"].allSatisfy { bd.decodeBool(from: $0) == false })
        #expect(["true", "TRUE", "trUe"].allSatisfy { bd.decodeBool(from: $0) == true })
        #expect(["false", "FALSE", "faLse"].allSatisfy { bd.decodeBool(from: $0) == false })
        #expect(["_true_", "_false_", "11", "00"].allSatisfy { bd.decodeBool(from: $0) == nil })
    }

    @available(Configuration 1.0, *)
    @Test("boolDecoder, only .oneZero boolean strings enabled")
    func boolDecoderOnlyOneZeroBooleanStringsEnabled() throws {
        let bd = BoolDecoder(booleanStrings: [.oneZero])
        #expect(bd.decodeBool(from: "1") == true)
        #expect(bd.decodeBool(from: "0") == false)
        #expect(bd.decodeBool(from: "true") == nil)
        #expect(bd.decodeBool(from: "false") == nil)
        #expect(bd.decodeBool(from: "yes") == nil)
        #expect(bd.decodeBool(from: "no") == nil)
    }
}
