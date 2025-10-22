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
import ConfigurationTestingInternal
@testable import Configuration
import Foundation
import ConfigurationTesting
import SystemPackage

private let resourcesPath = FilePath(try! #require(Bundle.module.path(forResource: "Resources", ofType: nil)))
let jsonConfigFile = resourcesPath.appending("/config.json")

struct JSONFileProviderTests {

    @available(Configuration 1.0, *)
    var provider: JSONSnapshot {
        get throws {
            try JSONSnapshot(
                data: Data(contentsOf: URL(filePath: jsonConfigFile.string)),
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
            TestProvider[20 values: bool=1, booly.array=1,0, byteChunky.array=bWFnaWM=,bWFnaWMy, bytes=bWFnaWM=, double=3.14, doubly.array=3.14,2.72, int=42, inty.array=42,24, other.bool=0, other.booly.array=0,1,1, other.byteChunky.array=bWFnaWM=,bWFnaWMy,bWFnaWM=, other.bytes=bWFnaWMy, other.double=2.72, other.doubly.array=0.9,1.8, other.int=24, other.inty.array=16,32, other.string=Other Hello, other.stringy.array=Hello,Swift, string=Hello, stringy.array=Hello,World]
            """#
        try #expect(provider.debugDescription == expectedDebugDescription)
    }

    @available(Configuration 1.0, *)
    @Test func compat() async throws {
        try await ProviderCompatTest(
            provider: FileProvider<JSONSnapshot>(filePath: jsonConfigFile)
        )
        .runTest()
    }
}
