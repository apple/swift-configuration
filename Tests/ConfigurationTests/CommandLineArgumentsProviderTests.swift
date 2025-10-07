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

#if CommandLineArgumentsSupport

import Testing
import ConfigurationTestingInternal
@testable import Configuration
import Foundation
import ConfigurationTesting

struct CommandLineArgumentsProviderTests {

    @available(Configuration 1.0, *)
    var provider: CommandLineArgumentsProvider {
        // Convert magic byte arrays to base64
        let magicBase64 = "bWFnaWM="
        let magic2Base64 = "bWFnaWMy"

        // Create a provider with the expected test data format for ProviderCompatTest
        return CommandLineArgumentsProvider(arguments: [
            "program",
            "--string", "Hello",
            "--other-string", "Other Hello",
            "--int", "42",
            "--other-int", "24",
            "--double", "3.14",
            "--other-double", "2.72",
            "--bool", "true",
            "--other-bool", "false",
            "--bytes", magicBase64,
            "--other-bytes", magic2Base64,
            "--stringy-array", "Hello", "World",
            "--other-stringy-array", "Hello", "Swift",
            "--inty-array", "42", "24",
            "--other-inty-array", "16", "32",
            "--doubly-array", "3.14", "2.72",
            "--other-doubly-array", "0.9", "1.8",
            "--booly-array", "true", "false",
            "--other-booly-array", "false", "true", "true",
            "--byte-chunky-array", magicBase64, magic2Base64,
            "--other-byte-chunky-array", magicBase64, magic2Base64, magicBase64,
        ])
    }

    @available(Configuration 1.0, *)
    @Test func printingDescription() throws {
        let expectedDescription = #"""
            CommandLineArgumentsProvider[20 values]
            """#
        #expect(provider.description == expectedDescription)
    }

    @available(Configuration 1.0, *)
    @Test func printingDebugDescription() throws {
        let expectedDebugDescription = #"""
            CommandLineArgumentsProvider[20 values: --bool=true, --booly-array=true,false, --byte-chunky-array=bWFnaWM=,bWFnaWMy, --bytes=bWFnaWM=, --double=3.14, --doubly-array=3.14,2.72, --int=42, --inty-array=42,24, --other-bool=false, --other-booly-array=false,true,true, --other-byte-chunky-array=bWFnaWM=,bWFnaWMy,bWFnaWM=, --other-bytes=bWFnaWMy, --other-double=2.72, --other-doubly-array=0.9,1.8, --other-int=24, --other-inty-array=16,32, --other-string=Other Hello, --other-stringy-array=Hello,Swift, --string=Hello, --stringy-array=Hello,World]
            """#
        #expect(provider.debugDescription == expectedDebugDescription)
    }

    @available(Configuration 1.0, *)
    @Test func compat() async throws {
        try await ProviderCompatTest(provider: provider).run()
    }

    @available(Configuration 1.0, *)
    @Test func secretSpecifier() throws {
        let provider = CommandLineArgumentsProvider(
            arguments: ["program", "--api-token", "s3cret", "--hostname", "localhost"],
            secretsSpecifier: .specific(["--api-token"])
        )
        #expect(try provider.value(forKey: ["api", "token"], type: .string).value?.isSecret == true)
        #expect(try provider.value(forKey: ["hostname"], type: .string).value?.isSecret == false)
    }
}

#endif
