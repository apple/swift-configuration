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
import Metrics
import SystemPackage

struct YAMLReloadingFileProviderTests {

    @available(Configuration 1.0, *)
    var provider: ReloadingFileProvider<YAMLSnapshot> {
        get async throws {
            let fileSystem = InMemoryFileSystem(files: [
                "/etc/config.yaml": .file(timestamp: .now, contents: yamlTestFileContents)
            ])
            return try await ReloadingFileProvider<YAMLSnapshot>(
                parsingOptions: .default,
                filePath: "/etc/config.yaml",
                allowMissing: false,
                pollInterval: .seconds(1),
                fileSystem: fileSystem,
                logger: .noop,
                metrics: NOOPMetricsHandler.instance
            )
        }
    }

    @available(Configuration 1.0, *)
    @Test func printingDescription() async throws {
        let expectedDescription = #"""
            ReloadingFileProvider<YAMLSnapshot>[20 values]
            """#
        #expect(try await provider.description == expectedDescription)
    }

    @available(Configuration 1.0, *)
    @Test func printingDebugDescription() async throws {
        let expectedDebugDescription = #"""
            ReloadingFileProvider<YAMLSnapshot>[20 values: bool=true, booly.array=true,false, byteChunky.array=bWFnaWM=,bWFnaWMy, bytes=bWFnaWM=, double=3.14, doubly.array=3.14,2.72, int=42, inty.array=42,24, other.bool=false, other.booly.array=false,true,true, other.byteChunky.array=bWFnaWM=,bWFnaWMy,bWFnaWM=, other.bytes=bWFnaWMy, other.double=2.72, other.doubly.array=0.9,1.8, other.int=24, other.inty.array=16,32, other.string=Other Hello, other.stringy.array=Hello,Swift, string=Hello, stringy.array=Hello,World]
            """#
        #expect(try await provider.debugDescription == expectedDebugDescription)
    }

    @available(Configuration 1.0, *)
    @Test func compat() async throws {
        try await ProviderCompatTest(provider: provider).runTest()
    }
}

#endif
