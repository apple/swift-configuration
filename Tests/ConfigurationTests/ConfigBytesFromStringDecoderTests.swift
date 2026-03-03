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

struct ConfigBytesFromStringDecoderTests {

    @available(Configuration 1.0, *)
    @Test func base64DecoderValidStrings() {
        let decoder = ConfigBytesFromBase64StringDecoder()

        // Test "Hello World" in base64
        let helloWorldB64 = "SGVsbG8gV29ybGQ="
        let expectedHelloWorld: [UInt8] = [72, 101, 108, 108, 111, 32, 87, 111, 114, 108, 100]
        #expect(decoder.decode(helloWorldB64) == expectedHelloWorld)

        // Test empty string
        #expect(decoder.decode("") == [])
    }

    @available(Configuration 1.0, *)
    @Test func base64StaticConvenienceMethod() {
        let decoder: any ConfigBytesFromStringDecoder = .base64
        // "Hello" in base64
        let testString = "SGVsbG8="
        let expected: [UInt8] = [72, 101, 108, 108, 111]
        #expect(decoder.decode(testString) == expected)
    }

    @available(Configuration 1.0, *)
    @Test func hexDecoderValidStrings() {
        let decoder = ConfigBytesFromHexStringDecoder()

        // Test "Hello" in hex (uppercase)
        let helloHexUpper = "48656C6C6F"
        let expectedHello: [UInt8] = [72, 101, 108, 108, 111]
        #expect(decoder.decode(helloHexUpper) == expectedHello)

        // Test "Hello" in hex (lowercase)
        let helloHexLower = "48656c6c6f"
        #expect(decoder.decode(helloHexLower) == expectedHello)

        // Test mixed case
        let helloHexMixed = "48656C6c6F"
        #expect(decoder.decode(helloHexMixed) == expectedHello)

        // Test empty string
        #expect(decoder.decode("") == [])

        // Test single byte values
        #expect(decoder.decode("00") == [0])
        #expect(decoder.decode("FF") == [255])
        #expect(decoder.decode("ff") == [255])
    }

    @available(Configuration 1.0, *)
    @Test func hexStaticConvenienceMethod() {
        let decoder: any ConfigBytesFromStringDecoder = .hex
        // "Hello" in hex
        let testString = "48656C6C6F"
        let expected: [UInt8] = [72, 101, 108, 108, 111]
        #expect(decoder.decode(testString) == expected)
    }
}
