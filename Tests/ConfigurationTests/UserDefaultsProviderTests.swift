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

#if canImport(Foundation)
import Testing
@testable import Configuration
import Foundation

struct UserDefaultsProviderTests {

    /// Creates a fresh UserDefaults suite for testing.
    private func makeTestDefaults(
        flat values: [String: Any]
    ) -> UserDefaults {
        let suiteName = "com.test.UserDefaultsProviderTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        for (key, value) in values {
            defaults.set(value, forKey: key)
        }
        return defaults
    }

    // MARK: - Flat mode tests

    @available(Configuration 1.0, *)
    @Test func flatStringLookup() throws {
        let defaults = makeTestDefaults(flat: ["app.name": "MyApp"])
        let provider = UserDefaultsProvider(defaults: defaults)
        let result = try provider.value(forKey: AbsoluteConfigKey("app.name"), type: .string)
        #expect(result.value?.content == .string("MyApp"))
    }

    @available(Configuration 1.0, *)
    @Test func flatIntLookup() throws {
        let defaults = makeTestDefaults(flat: ["http.timeout": 30])
        let provider = UserDefaultsProvider(defaults: defaults)
        let result = try provider.value(forKey: AbsoluteConfigKey("http.timeout"), type: .int)
        #expect(result.value?.content == .int(30))
    }

    @available(Configuration 1.0, *)
    @Test func flatDoubleLookup() throws {
        let defaults = makeTestDefaults(flat: ["rate.limit": 3.14])
        let provider = UserDefaultsProvider(defaults: defaults)
        let result = try provider.value(forKey: AbsoluteConfigKey("rate.limit"), type: .double)
        #expect(result.value?.content == .double(3.14))
    }

    @available(Configuration 1.0, *)
    @Test func flatBoolLookup() throws {
        let defaults = makeTestDefaults(flat: ["feature.enabled": true])
        let provider = UserDefaultsProvider(defaults: defaults)
        let result = try provider.value(forKey: AbsoluteConfigKey("feature.enabled"), type: .bool)
        #expect(result.value?.content == .bool(true))
    }

    @available(Configuration 1.0, *)
    @Test func flatMissingKeyReturnsNilValue() throws {
        let defaults = makeTestDefaults(flat: [:])
        let provider = UserDefaultsProvider(defaults: defaults)
        let result = try provider.value(forKey: AbsoluteConfigKey("nonexistent"), type: .string)
        #expect(result.value == nil)
    }

    @available(Configuration 1.0, *)
    @Test func flatStringArrayLookup() throws {
        let defaults = makeTestDefaults(flat: ["tags": ["swift", "ios"]])
        let provider = UserDefaultsProvider(defaults: defaults)
        let result = try provider.value(forKey: AbsoluteConfigKey("tags"), type: .stringArray)
        #expect(result.value?.content == .stringArray(["swift", "ios"]))
    }

    // MARK: - Nested mode tests

    @available(Configuration 1.0, *)
    @Test func nestedLookup() throws {
        let suiteName = "com.test.UserDefaultsProviderTests.nested.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.set(
            ["http.timeout": 60, "app.name": "NestedApp"] as [String: Any],
            forKey: "com.apple.configuration.managed"
        )
        let provider = UserDefaultsProvider.nested(
            dictionaryKey: "com.apple.configuration.managed",
            defaults: defaults
        )
        let result = try provider.value(forKey: AbsoluteConfigKey("http.timeout"), type: .int)
        #expect(result.value?.content == .int(60))

        let nameResult = try provider.value(forKey: AbsoluteConfigKey("app.name"), type: .string)
        #expect(nameResult.value?.content == .string("NestedApp"))
    }

    @available(Configuration 1.0, *)
    @Test func nestedMissingDictionaryReturnsNilValue() throws {
        let defaults = makeTestDefaults(flat: [:])
        let provider = UserDefaultsProvider.nested(
            dictionaryKey: "nonexistent.dict",
            defaults: defaults
        )
        let result = try provider.value(forKey: AbsoluteConfigKey("some.key"), type: .string)
        #expect(result.value == nil)
    }

    // MARK: - Description tests

    @available(Configuration 1.0, *)
    @Test func flatDescription() throws {
        let provider = UserDefaultsProvider(defaults: makeTestDefaults(flat: [:]))
        #expect(provider.description == "UserDefaultsProvider[flat]")
    }

    @available(Configuration 1.0, *)
    @Test func nestedDescription() throws {
        let provider = UserDefaultsProvider.nested(
            dictionaryKey: "com.apple.configuration.managed",
            defaults: makeTestDefaults(flat: [:])
        )
        #expect(provider.description == "UserDefaultsProvider[nested: com.apple.configuration.managed]")
    }

    // MARK: - Type conversion tests

    @available(Configuration 1.0, *)
    @Test func intFromStringConversion() throws {
        let defaults = makeTestDefaults(flat: ["port": "8080"])
        let provider = UserDefaultsProvider(defaults: defaults)
        let result = try provider.value(forKey: AbsoluteConfigKey("port"), type: .int)
        #expect(result.value?.content == .int(8080))
    }

    @available(Configuration 1.0, *)
    @Test func boolFromStringConversion() throws {
        let defaults = makeTestDefaults(flat: ["debug": "yes"])
        let provider = UserDefaultsProvider(defaults: defaults)
        let result = try provider.value(forKey: AbsoluteConfigKey("debug"), type: .bool)
        #expect(result.value?.content == .bool(true))
    }

    @available(Configuration 1.0, *)
    @Test func typeMismatchThrows() throws {
        let defaults = makeTestDefaults(flat: ["name": "hello"])
        let provider = UserDefaultsProvider(defaults: defaults)
        #expect(throws: ConfigError.self) {
            try provider.value(forKey: AbsoluteConfigKey("name"), type: .intArray)
        }
    }

    // MARK: - Provider protocol conformance

    @available(Configuration 1.0, *)
    @Test func providerName() throws {
        let provider = UserDefaultsProvider(defaults: makeTestDefaults(flat: [:]))
        #expect(provider.providerName == "UserDefaultsProvider[flat]")
    }

    @available(Configuration 1.0, *)
    @Test func fetchValueReturnsSameAsValue() async throws {
        let defaults = makeTestDefaults(flat: ["key": "value"])
        let provider = UserDefaultsProvider(defaults: defaults)
        let syncResult = try provider.value(forKey: AbsoluteConfigKey("key"), type: .string)
        let asyncResult = try await provider.fetchValue(forKey: AbsoluteConfigKey("key"), type: .string)
        #expect(syncResult == asyncResult)
    }

    @available(Configuration 1.0, *)
    @Test func snapshotReturnsCorrectValue() throws {
        let defaults = makeTestDefaults(flat: ["test": "snapshot"])
        let provider = UserDefaultsProvider(defaults: defaults)
        let snap = provider.snapshot()
        let result = try snap.value(forKey: AbsoluteConfigKey("test"), type: .string)
        #expect(result.value?.content == .string("snapshot"))
    }
}
#endif
