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

struct SecretMarkingProviderTests {

    @available(Configuration 1.0, *)
    @Test func marksMatchingKeysAsSecret() throws {
        let upstream = InMemoryProvider(values: [
            "database.password": "secret-pass",
            "database.host": "localhost",
        ])
        let provider = SecretMarkingProvider(upstream: upstream) { key in
            key.description.contains("password")
        }

        let passwordResult = try provider.value(forKey: ["database", "password"], type: .string)
        #expect(passwordResult.value?.isSecret == true)

        let hostResult = try provider.value(forKey: ["database", "host"], type: .string)
        #expect(hostResult.value?.isSecret == false)
    }

    @available(Configuration 1.0, *)
    @Test func preservesExistingSecrets() throws {
        let upstream = InMemoryProvider(values: [
            "api.key": ConfigValue(.string("already-secret"), isSecret: true),
            "other.key": ConfigValue(.string("not-secret"), isSecret: false),
        ])
        // Predicate doesn't match "api.key" but it should stay secret
        let provider = SecretMarkingProvider(upstream: upstream) { _ in false }

        let apiKeyResult = try provider.value(forKey: ["api", "key"], type: .string)
        #expect(apiKeyResult.value?.isSecret == true)

        let otherResult = try provider.value(forKey: ["other", "key"], type: .string)
        #expect(otherResult.value?.isSecret == false)
    }

    @available(Configuration 1.0, *)
    @Test func fetchValueMarksSecret() async throws {
        let upstream = InMemoryProvider(values: ["api.secret": "token"])
        let provider = upstream.markSecrets { $0.description.contains("secret") }

        let result = try await provider.fetchValue(forKey: ["api", "secret"], type: .string)
        #expect(result.value?.isSecret == true)
    }

    @available(Configuration 1.0, *)
    @Test func watchValueMarksSecret() async throws {
        let upstream = InMemoryProvider(values: ["jwt.token": "eyJ..."])
        let provider = upstream.markSecrets { $0.description.contains("token") }

        try await provider.watchValue(forKey: ["jwt", "token"], type: .string) { sequence in
            for try await result in sequence {
                let lookupResult = try result.get()
                #expect(lookupResult.value?.isSecret == true)
                break
            }
        }
    }

    @available(Configuration 1.0, *)
    @Test func snapshotMarksSecret() throws {
        let upstream = InMemoryProvider(values: ["db.password": "pass", "db.name": "mydb"])
        let provider = upstream.markSecrets { $0.description.contains("password") }
        let snapshot = provider.snapshot()

        #expect(try snapshot.value(forKey: ["db", "password"], type: .string).value?.isSecret == true)
        #expect(try snapshot.value(forKey: ["db", "name"], type: .string).value?.isSecret == false)
    }

    @available(Configuration 1.0, *)
    @Test func watchSnapshotMarksSecret() async throws {
        let upstream = InMemoryProvider(values: ["auth.secret": "shh"])
        let provider = upstream.markSecrets { $0.description.contains("secret") }

        try await provider.watchSnapshot { sequence in
            for try await snapshot in sequence {
                let result = try snapshot.value(forKey: ["auth", "secret"], type: .string)
                #expect(result.value?.isSecret == true)
                break
            }
        }
    }

    @available(Configuration 1.0, *)
    @Test func providerName() {
        let upstream = InMemoryProvider(name: "test", values: [:])
        let provider = SecretMarkingProvider(upstream: upstream) { _ in false }
        #expect(provider.providerName == "SecretMarkingProvider[upstream: InMemoryProvider[test]]")
    }

    @available(Configuration 1.0, *)
    @Test func description() {
        let upstream = InMemoryProvider(name: "test", values: [:])
        let provider = SecretMarkingProvider(upstream: upstream) { _ in false }
        #expect(provider.description == "SecretMarkingProvider[upstream: InMemoryProvider[test, 0 values]]")
    }

    @available(Configuration 1.0, *)
    @Test func nilValueHandling() throws {
        let upstream = InMemoryProvider(values: [:])
        let provider = upstream.markSecrets { _ in true }
        let result = try provider.value(forKey: ["nonexistent"], type: .string)
        #expect(result.value == nil)
    }

    @available(Configuration 1.0, *)
    @Test func markSecretsForKeysOperator() throws {
        let upstream = InMemoryProvider(values: [
            "database.password": "pass",
            "database.host": "localhost",
        ])
        let provider = upstream.markSecretsForKeys([["database", "password"]])

        #expect(try provider.value(forKey: ["database", "password"], type: .string).value?.isSecret == true)
        #expect(try provider.value(forKey: ["database", "host"], type: .string).value?.isSecret == false)
    }

    @available(Configuration 1.0, *)
    @Test func chainingWithKeyMapping() throws {
        let upstream = InMemoryProvider(values: ["app.database.password": "secret"])
        let provider = upstream
            .prefixKeys(with: "myapp")
            .markSecrets { $0.description.contains("password") }

        let result = try provider.value(forKey: ["database", "password"], type: .string)
        #expect(result.value?.isSecret == true)
    }

    @available(Configuration 1.0, *)
    @Test func compat() async throws {
        let upstream = InMemoryProvider(
            name: "test",
            values: [
                "string": "Hello",
                "other.string": "Other Hello",
                "int": 42,
                "other.int": 24,
                "double": 3.14,
                "other.double": 2.72,
                "bool": true,
                "other.bool": false,
                "bytes": ConfigValue(.magic, isSecret: false),
                "other.bytes": ConfigValue(.magic2, isSecret: false),
                "stringy.array": ConfigValue(["Hello", "World"], isSecret: false),
                "other.stringy.array": ConfigValue(["Hello", "Swift"], isSecret: false),
                "inty.array": ConfigValue([42, 24], isSecret: false),
                "other.inty.array": ConfigValue([16, 32], isSecret: false),
                "doubly.array": ConfigValue([3.14, 2.72], isSecret: false),
                "other.doubly.array": ConfigValue([0.9, 1.8], isSecret: false),
                "booly.array": ConfigValue([true, false], isSecret: false),
                "other.booly.array": ConfigValue([false, true, true], isSecret: false),
                "byteChunky.array": ConfigValue([.magic, .magic2], isSecret: false),
                "other.byteChunky.array": ConfigValue([.magic, .magic2, .magic], isSecret: false),
            ]
        )
        let provider = SecretMarkingProvider(upstream: upstream) { _ in false }
        try await ProviderCompatTest(provider: provider).runTest()
    }
}
