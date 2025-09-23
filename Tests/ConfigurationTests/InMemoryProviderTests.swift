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

struct InMemoryProviderTests {
    let provider: InMemoryProvider
    init() {
        provider = InMemoryProvider(
            name: "test",
            values: [
                "string": .init("Hello", isSecret: false),
                "other.string": .init("Other Hello", isSecret: false),
                "int": .init(42, isSecret: false),
                "other.int": .init(24, isSecret: false),
                "double": .init(3.14, isSecret: false),
                "other.double": .init(2.72, isSecret: false),
                "bool": .init(true, isSecret: false),
                "other.bool": .init(false, isSecret: false),
                "bytes": .init(.magic, isSecret: false),
                "other.bytes": .init(.magic2, isSecret: false),
                "stringy.array": .init(["Hello", "World"], isSecret: false),
                "other.stringy.array": .init(["Hello", "Swift"], isSecret: false),
                "inty.array": .init([42, 24], isSecret: false),
                "other.inty.array": .init([16, 32], isSecret: false),
                "doubly.array": .init([3.14, 2.72], isSecret: false),
                "other.doubly.array": .init([0.9, 1.8], isSecret: false),
                "booly.array": .init([true, false], isSecret: false),
                "other.booly.array": .init([false, true, true], isSecret: false),
                "byteChunky.array": .init([.magic, .magic2], isSecret: false),
                "other.byteChunky.array": .init([.magic, .magic2, .magic], isSecret: false),
            ]
        )
    }

    @Test func printingDescription() throws {
        let expectedDescription = #"""
            InMemoryProvider[test, 20 values]
            """#
        #expect(provider.description == expectedDescription)
    }

    @Test func printingDebugDescription() throws {
        let expectedDebugDescription = #"""
            InMemoryProvider[test, 20 values: bool=[bool: true], booly.array=[boolArray: true, false], byteChunky.array=[byteChunkArray: 5 bytes, prefix: 6d61676963, 6 bytes, prefix: 6d6167696332], bytes=[bytes: 5 bytes, prefix: 6d61676963], double=[double: 3.14], doubly.array=[doubleArray: 3.14, 2.72], int=[int: 42], inty.array=[intArray: 42, 24], other.bool=[bool: false], other.booly.array=[boolArray: false, true, true], other.byteChunky.array=[byteChunkArray: 5 bytes, prefix: 6d61676963, 6 bytes, prefix: 6d6167696332, 5 bytes, prefix: 6d61676963], other.bytes=[bytes: 6 bytes, prefix: 6d6167696332], other.double=[double: 2.72], other.doubly.array=[doubleArray: 0.9, 1.8], other.int=[int: 24], other.inty.array=[intArray: 16, 32], other.string=[string: Other Hello], other.stringy.array=[stringArray: Hello, Swift], string=[string: Hello], stringy.array=[stringArray: Hello, World]]
            """#
        #expect(provider.debugDescription == expectedDebugDescription)
    }

    @Test func compat() async throws {
        try await ProviderCompatTest(provider: provider).run()
    }
}
