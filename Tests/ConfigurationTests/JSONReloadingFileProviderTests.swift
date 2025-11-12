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

#if JSONSupport && ReloadingSupport

import Testing
import ConfigurationTestingInternal
@testable import Configuration
import Foundation
import ConfigurationTesting
import Logging
import Metrics
import SystemPackage

struct JSONReloadingFileProviderTests {

    @available(Configuration 1.0, *)
    var provider: ReloadingFileProvider<JSONSnapshot> {
        get async throws {
            let fileSystem = InMemoryFileSystem(files: [
                "/etc/config.json": .file(timestamp: .now, contents: jsonTestFileContents)
            ])
            return try await ReloadingFileProvider<JSONSnapshot>(
                parsingOptions: .default,
                filePath: "/etc/config.json",
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
            ReloadingFileProvider<JSONSnapshot>[20 values]
            """#
        #expect(try await provider.description == expectedDescription)
    }

    @available(Configuration 1.0, *)
    @Test func printingDebugDescription() async throws {
        let expectedDebugDescription = #"""
            ReloadingFileProvider<JSONSnapshot>[20 values: bool=1, booly.array=1,0, byteChunky.array=bWFnaWM=,bWFnaWMy, bytes=bWFnaWM=, double=3.14, doubly.array=3.14,2.72, int=42, inty.array=42,24, other.bool=0, other.booly.array=0,1,1, other.byteChunky.array=bWFnaWM=,bWFnaWMy,bWFnaWM=, other.bytes=bWFnaWMy, other.double=2.72, other.doubly.array=0.9,1.8, other.int=24, other.inty.array=16,32, other.string=Other Hello, other.stringy.array=Hello,Swift, string=Hello, stringy.array=Hello,World]
            """#
        #expect(try await provider.debugDescription == expectedDebugDescription)
    }

    @available(Configuration 1.0, *)
    @Test func compat() async throws {
        try await ProviderCompatTest(provider: provider).runTest()
    }
}

#endif
