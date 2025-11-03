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

@testable import Configuration
import Foundation
import ConfigurationTestingInternal
import SystemPackage

@available(Configuration 1.0, *)
struct TestSnapshot: FileConfigSnapshot {

    struct Input: FileParsingOptions {
        static var `default`: TestSnapshot.Input {
            .init()
        }
    }

    var values: [String: ConfigValue]

    var providerName: String

    func value(forKey key: AbsoluteConfigKey, type: ConfigType) throws -> LookupResult {
        let encodedKey = SeparatorKeyEncoder.dotSeparated.encode(key)
        return LookupResult(encodedKey: encodedKey, value: values[encodedKey])
    }

    init(values: [String: ConfigValue], providerName: String) {
        self.values = values
        self.providerName = providerName
    }

    init(contents: String, providerName: String) throws {
        var values: [String: ConfigValue] = [:]

        // Simple key=value parser for testing
        for line in contents.split(separator: "\n") {
            let parts = line.split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
                let value = String(parts[1]).trimmingCharacters(in: .whitespaces)
                values[key] = .init(.string(value), isSecret: false)
            }
        }
        self.init(values: values, providerName: providerName)
    }

    init(data: RawSpan, providerName: String, parsingOptions: Input) throws {
        try self.init(contents: String(decoding: Data(data), as: UTF8.self), providerName: providerName)
    }

    var description: String {
        "TestSnapshot"
    }

    var debugDescription: String {
        description
    }
}

@available(Configuration 1.0, *)
extension InMemoryFileSystem.FileData {
    static func file(contents: String) -> Self {
        .file(Data(contents.utf8))
    }
}

@available(Configuration 1.0, *)
extension InMemoryFileSystem.FileInfo {
    static func file(timestamp: Date, contents: String) -> Self {
        .init(lastModifiedTimestamp: timestamp, data: .file(contents: contents))
    }
}

@available(Configuration 1.0, *)
func withTestFileSystem<Return>(
    _ body: (InMemoryFileSystem, FilePath, Date) async throws -> Return
) async throws -> Return {
    let filePath = FilePath("/test/config.txt")
    let originalTimestamp = Date(timeIntervalSince1970: 1_750_688_537)
    let fileSystem = InMemoryFileSystem(
        files: [
            filePath: .file(
                timestamp: originalTimestamp,
                contents: """
                    key1=value1
                    key2=value2
                    """
            )
        ]
    )
    return try await body(fileSystem, filePath, originalTimestamp)
}
