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
@testable import Configuration
import Foundation
import ConfigurationTestingInternal
import ConfigurationTesting
import SystemPackage

struct DirectoryFilesProviderTests {

    /// Creates test files for the provider.
    @available(Configuration 1.0, *)
    static var testFiles: [FilePath: InMemoryFileSystem.FileInfo] {
        let stringValues: [String: String] = [
            "string": "Hello",
            "other-string": "Other Hello",
            "int": "42",
            "other-int": "24",
            "double": "3.14",
            "other-double": "2.72",
            "bool": "true",
            "other-bool": "false",
            "stringy-array": "Hello,World",
            "other-stringy-array": "Hello,Swift",
            "inty-array": "42,24",
            "other-inty-array": "16,32",
            "doubly-array": "3.14,2.72",
            "other-doubly-array": "0.9,1.8",
            "booly-array": "true,false",
            "other-booly-array": "false,true,true",
            "database-password": "secretpass123",
        ]
        let binaryValues: [String: [UInt8]] = [
            "bytes": .magic,
            "other-bytes": .magic2,
            "byteChunky-array": .magic,
            "other-byteChunky-array": .magic2,
        ]
        let contents = stringValues.mapValues { Data($0.utf8) }
            .merging(binaryValues.mapValues { Data($0) }) { a, b in a }
        let tuples = contents.map { key, value -> (FilePath, InMemoryFileSystem.FileInfo) in
            (
                FilePath("/test/\(key)"),
                .init(lastModifiedTimestamp: Date(timeIntervalSince1970: 1_750_688_537), data: .file(value))
            )
        }
        return Dictionary(uniqueKeysWithValues: tuples)
    }

    @available(Configuration 1.0, *)
    @Test func printingDescription() async throws {
        let fileSystem = InMemoryFileSystem(files: Self.testFiles)
        let provider = try await DirectoryFilesProvider(
            directoryPath: "/test",
            fileSystem: fileSystem
        )

        #expect(provider.description == "DirectoryFilesProvider[21 files]")
    }

    @available(Configuration 1.0, *)
    @Test func printingDebugDescription() async throws {
        let fileSystem = InMemoryFileSystem(files: Self.testFiles)
        let provider = try await DirectoryFilesProvider(
            directoryPath: "/test",
            fileSystem: fileSystem,
            secretsSpecifier: .specific(["database-password"])
        )

        let expectedDebugDescription = #"""
            DirectoryFilesProvider[21 files: bool=true, booly-array=true,false, byteChunky-array=magic, bytes=magic, database-password=<REDACTED>, double=3.14, doubly-array=3.14,2.72, int=42, inty-array=42,24, other-bool=false, other-booly-array=false,true,true, other-byteChunky-array=magic2, other-bytes=magic2, other-double=2.72, other-doubly-array=0.9,1.8, other-int=24, other-inty-array=16,32, other-string=Other Hello, other-stringy-array=Hello,Swift, string=Hello, stringy-array=Hello,World]
            """#
        #expect(provider.debugDescription == expectedDebugDescription)
    }

    @available(Configuration 1.0, *)
    @Test func compat() async throws {
        let fileSystem = InMemoryFileSystem(files: Self.testFiles)
        let provider = try await DirectoryFilesProvider(
            directoryPath: "/test",
            fileSystem: fileSystem
        )
        try await ProviderCompatTest(
            provider: provider,
            configuration: .init(overrides: [
                "byteChunky.array": .byteChunkArray([.magic]),
                "other.byteChunky.array": .byteChunkArray([.magic2]),
            ])
        )
        .runTest()
    }
}
