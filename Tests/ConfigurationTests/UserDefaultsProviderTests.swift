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

#if canImport(Darwin)
import Testing
import ConfigurationTestingInternal
@testable import Configuration
import Foundation
import ConfigurationTesting

struct UserDefaultsProviderTests {

    /// A unique suite name for test isolation.
    private static let testSuiteName = "com.apple.swift-configuration.tests.\(UUID().uuidString)"

    /// Creates a UserDefaults instance populated with the standard test data.
    private static func makeTestDefaults() -> UserDefaults {
        let defaults = UserDefaults(suiteName: testSuiteName)!
        defaults.set("Hello", forKey: "string")
        defaults.set("Other Hello", forKey: "other.string")
        defaults.set(42, forKey: "int")
        defaults.set(24, forKey: "other.int")
        defaults.set(3.14, forKey: "double")
        defaults.set(2.72, forKey: "other.double")
        defaults.set(true, forKey: "bool")
        defaults.set(false, forKey: "other.bool")
        defaults.set(Data([UInt8].magic), forKey: "bytes")
        defaults.set(Data([UInt8].magic2), forKey: "other.bytes")
        defaults.set(["Hello", "World"], forKey: "stringy.array")
        defaults.set(["Hello", "Swift"], forKey: "other.stringy.array")
        defaults.set([42, 24], forKey: "inty.array")
        defaults.set([16, 32], forKey: "other.inty.array")
        defaults.set([3.14, 2.72], forKey: "doubly.array")
        defaults.set([0.9, 1.8], forKey: "other.doubly.array")
        defaults.set([true, false], forKey: "booly.array")
        defaults.set([false, true, true], forKey: "other.booly.array")
        defaults.set([Data([UInt8].magic), Data([UInt8].magic2)], forKey: "byteChunky.array")
        defaults.set(
            [Data([UInt8].magic), Data([UInt8].magic2), Data([UInt8].magic)],
            forKey: "other.byteChunky.array"
        )
        return defaults
    }

    @available(Configuration 1.0, *)
    var provider: UserDefaultsProvider {
        let defaults = Self.makeTestDefaults()
        return UserDefaultsProvider(name: "test", defaults: defaults)
    }

    @available(Configuration 1.0, *)
    @Test func printingDescription() throws {
        let expectedDescription = "UserDefaultsProvider[test]"
        #expect(provider.description == expectedDescription)
    }

    @available(Configuration 1.0, *)
    @Test func stringValue() throws {
        let result = try provider.value(forKey: "string", type: .string)
        #expect(result.value?.content == .string("Hello"))
        #expect(result.encodedKey == "string")
    }

    @available(Configuration 1.0, *)
    @Test func intValue() throws {
        let result = try provider.value(forKey: "int", type: .int)
        #expect(result.value?.content == .int(42))
    }

    @available(Configuration 1.0, *)
    @Test func doubleValue() throws {
        let result = try provider.value(forKey: "double", type: .double)
        #expect(result.value?.content == .double(3.14))
    }

    @available(Configuration 1.0, *)
    @Test func boolValue() throws {
        let result = try provider.value(forKey: "bool", type: .bool)
        #expect(result.value?.content == .bool(true))
    }

    @available(Configuration 1.0, *)
    @Test func bytesValue() throws {
        let result = try provider.value(forKey: "bytes", type: .bytes)
        #expect(result.value?.content == .bytes(.magic))
    }

    @available(Configuration 1.0, *)
    @Test func stringArrayValue() throws {
        let result = try provider.value(forKey: "stringy.array", type: .stringArray)
        #expect(result.value?.content == .stringArray(["Hello", "World"]))
    }

    @available(Configuration 1.0, *)
    @Test func missingValue() throws {
        let result = try provider.value(forKey: "nonexistent", type: .string)
        #expect(result.value == nil)
    }

    @available(Configuration 1.0, *)
    @Test func typeMismatch() throws {
        #expect(throws: ConfigError.self) {
            _ = try provider.value(forKey: "string", type: .int)
        }
    }

    @available(Configuration 1.0, *)
    @Test func nestedKey() throws {
        let result = try provider.value(forKey: "other.string", type: .string)
        #expect(result.value?.content == .string("Other Hello"))
    }

    @available(Configuration 1.0, *)
    @Test func snapshot() throws {
        let snap = provider.snapshot()
        let result = try snap.value(forKey: "string", type: .string)
        #expect(result.value?.content == .string("Hello"))
    }

    @available(Configuration 1.0, *)
    @Test func fetchValue() async throws {
        let result = try await provider.fetchValue(forKey: "int", type: .int)
        #expect(result.value?.content == .int(42))
    }

    @available(Configuration 1.0, *)
    @Test func compat() async throws {
        try await ProviderCompatTest(provider: provider).runTest()
    }
}
#endif
