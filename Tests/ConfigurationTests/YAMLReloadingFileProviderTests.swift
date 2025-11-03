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

#if YAMLSupport && ReloadingSupport

import Testing
import ConfigurationTestingInternal
@testable import Configuration
import Foundation
import ConfigurationTesting
import Logging
import SystemPackage

struct YAMLReloadingFileProviderTests {
    @available(Configuration 1.0, *)
    @Test func printingDescription() async throws {
        let provider = try await ReloadingFileProvider<YAMLSnapshot>(filePath: yamlConfigFile)
        let expectedDescription = #"""
            ReloadingFileProvider<YAMLSnapshot>[20 values]
            """#
        #expect(provider.description == expectedDescription)
    }

    @available(Configuration 1.0, *)
    @Test func printingDebugDescription() async throws {
        let provider = try await ReloadingFileProvider<YAMLSnapshot>(filePath: yamlConfigFile)
        let expectedDebugDescription = #"""
            ReloadingFileProvider<YAMLSnapshot>[20 values: bool=true, booly.array=true,false, byteChunky.array=bWFnaWM=,bWFnaWMy, bytes=bWFnaWM=, double=3.14, doubly.array=3.14,2.72, int=42, inty.array=42,24, other.bool=false, other.booly.array=false,true,true, other.byteChunky.array=bWFnaWM=,bWFnaWMy,bWFnaWM=, other.bytes=bWFnaWMy, other.double=2.72, other.doubly.array=0.9,1.8, other.int=24, other.inty.array=16,32, other.string=Other Hello, other.stringy.array=Hello,Swift, string=Hello, stringy.array=Hello,World]
            """#
        #expect(provider.debugDescription == expectedDebugDescription)
    }

    @available(Configuration 1.0, *)
    @Test func compat() async throws {
        let provider = try await ReloadingFileProvider<YAMLSnapshot>(filePath: yamlConfigFile)
        try await ProviderCompatTest(provider: provider).runTest()
    }

    @available(Configuration 1.0, *)
    @Test func initializationWithConfig() async throws {
        // Test initialization using config reader
        let envProvider = InMemoryProvider(values: [
            "yaml.filePath": ConfigValue(yamlConfigFile.string, isSecret: false),
            "yaml.pollIntervalSeconds": 30,
        ])
        let config = ConfigReader(provider: envProvider)

        let reloadingProvider = try await ReloadingFileProvider<YAMLSnapshot>(
            config: config.scoped(to: "yaml")
        )

        #expect(reloadingProvider.providerName == "ReloadingFileProvider<YAMLSnapshot>")
        #expect(reloadingProvider.description.contains("ReloadingFileProvider<YAMLSnapshot>[20 values]"))
    }
}

#endif
