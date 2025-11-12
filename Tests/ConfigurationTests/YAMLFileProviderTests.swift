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

#if YAMLSupport

import Testing
import ConfigurationTestingInternal
@testable import Configuration
import Foundation
import ConfigurationTesting
import SystemPackage

let yamlTestFileContents = """
    string: "Hello"
    int: 42
    double: 3.14
    bool: true
    bytes: "bWFnaWM="

    other:
        string: "Other Hello"
        int: 24
        double: 2.72
        bool: false
        bytes: "bWFnaWMy"

        stringy:
            array:
                - "Hello"
                - "Swift"
        inty:
            array:
                - 16
                - 32
        doubly:
            array:
                - 0.9
                - 1.8
        booly:
            array:
                - false
                - true
                - true
        byteChunky:
            array:
                - "bWFnaWM="
                - "bWFnaWMy"
                - "bWFnaWM="

    stringy:
        array:
            - "Hello"
            - "World"
    inty:
        array:
            - 42
            - 24
    doubly:
        array:
            - 3.14
            - 2.72
    booly:
        array:
            - true
            - false
    byteChunky:
        array:
            - "bWFnaWM="
            - "bWFnaWMy"

    """

struct YAMLFileProviderTests {

    @available(Configuration 1.0, *)
    var provider: YAMLSnapshot {
        get throws {
            try YAMLSnapshot(
                data: Data(yamlTestFileContents.utf8).bytes,
                providerName: "TestProvider",
                parsingOptions: .default
            )
        }
    }

    @available(Configuration 1.0, *)
    @Test func printingDescription() async throws {
        let expectedDescription = #"""
            TestProvider[20 values]
            """#
        try #expect(provider.description == expectedDescription)
    }

    @available(Configuration 1.0, *)
    @Test func printingDebugDescription() async throws {
        let expectedDebugDescription = #"""
            TestProvider[20 values: bool=true, booly.array=true,false, byteChunky.array=bWFnaWM=,bWFnaWMy, bytes=bWFnaWM=, double=3.14, doubly.array=3.14,2.72, int=42, inty.array=42,24, other.bool=false, other.booly.array=false,true,true, other.byteChunky.array=bWFnaWM=,bWFnaWMy,bWFnaWM=, other.bytes=bWFnaWMy, other.double=2.72, other.doubly.array=0.9,1.8, other.int=24, other.inty.array=16,32, other.string=Other Hello, other.stringy.array=Hello,Swift, string=Hello, stringy.array=Hello,World]
            """#
        try #expect(provider.debugDescription == expectedDebugDescription)
    }

    @available(Configuration 1.0, *)
    @Test func compat() async throws {
        let fileSystem = InMemoryFileSystem(files: [
            "/etc/config.yaml": .file(timestamp: .now, contents: yamlTestFileContents)
        ])
        try await ProviderCompatTest(
            provider: FileProvider<YAMLSnapshot>(
                parsingOptions: .default,
                filePath: "/etc/config.yaml",
                allowMissing: false,
                fileSystem: fileSystem
            )
        )
        .runTest()
    }
}

#endif
