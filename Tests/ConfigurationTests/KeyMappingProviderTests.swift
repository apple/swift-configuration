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

struct KeyMappingProviderTests {

    @Test func getValueWithMappedKey() throws {
        let upstream = InMemoryProvider(values: ["app.foo": "bar", "app.bar": "baz"])
        let mapper = KeyMappingProvider(upstream: upstream) { key in
            switch key {
            case ["foo"]:
                return ["app", "foo"]
            default:
                return key
            }
        }

        let fooResult = try mapper.value(forKey: ["foo"], type: .string)
        #expect(try fooResult.value?.content.asString == "bar")
        #expect(fooResult.encodedKey == "app.foo")

        let barResult = try mapper.value(forKey: ["app", "bar"], type: .string)
        #expect(try barResult.value?.content.asString == "baz")
        #expect(barResult.encodedKey == "app.bar")
    }

    @Test func fetchValueWithMappedKey() async throws {
        let upstream = InMemoryProvider(values: ["app.foo": "bar", "app.bar": "baz"])
        let mapper = KeyMappingProvider(upstream: upstream) { key in
            switch key {
            case ["foo"]:
                return ["app", "foo"]
            default:
                return key
            }
        }

        let fooResult = try await mapper.fetchValue(forKey: ["foo"], type: .string)
        #expect(try fooResult.value?.content.asString == "bar")
        #expect(fooResult.encodedKey == "app.foo")
    }

    @Test func watchValueWithMappedKey() async throws {
        let upstream = InMemoryProvider(values: ["app.foo": "bar", "app.bar": "baz"])
        let mapper = KeyMappingProvider(upstream: upstream) { key in
            switch key {
            case ["foo"]:
                return ["app", "foo"]
            default:
                return key
            }
        }

        var receivedResults: [Result<LookupResult, any Error>] = []
        try await mapper.watchValue(forKey: ["foo"], type: .string) { sequence in
            for try await result in sequence {
                receivedResults.append(result)
                break  // Only take the first result for this test
            }
        }
        #expect(receivedResults.count == 1)
        let result = try receivedResults[0].get()
        #expect(try result.value?.content.asString == "bar")
        #expect(result.encodedKey == "app.foo")
    }

    @Test func snapshotWithMappedKey() throws {
        let upstream = InMemoryProvider(values: ["app.foo": "bar", "app.bar": "baz"])
        let mapper = KeyMappingProvider(upstream: upstream) { key in
            switch key {
            case ["foo"]:
                return ["app", "foo"]
            default:
                return key
            }
        }

        let snapshot = mapper.snapshot()
        let fooResult = try snapshot.value(forKey: ["foo"], type: .string)
        #expect(try fooResult.value?.content.asString == "bar")
        #expect(fooResult.encodedKey == "app.foo")

        let otherResult = try snapshot.value(forKey: ["other"], type: .string)
        #expect(try otherResult.value?.content.asString == nil)
        #expect(otherResult.encodedKey == "other")
    }

    @Test func watchSnapshotWithMappedPrefix() async throws {
        let upstream = InMemoryProvider(values: ["app.foo": "bar", "app.bar": "baz"])
        let mapper = KeyMappingProvider(upstream: upstream) { key in
            switch key {
            case ["foo"]:
                return ["app", "foo"]
            default:
                return key
            }
        }

        var receivedSnapshots: [any ConfigSnapshotProtocol] = []
        try await mapper.watchSnapshot { sequence in
            for try await snapshot in sequence {
                receivedSnapshots.append(snapshot)
                break
            }
        }
        #expect(receivedSnapshots.count == 1)
        let snapshot = receivedSnapshots[0]
        let result = try snapshot.value(forKey: ["foo"], type: .string)
        #expect(try result.value?.content.asString == "bar")
        #expect(result.encodedKey == "app.foo")
    }

    @Test func providerName() {
        let upstream = InMemoryProvider(name: "test-upstream", values: [:])
        let mapper = KeyMappingProvider(upstream: upstream) { key in key }
        let expectedName = "KeyMappingProvider[upstream: InMemoryProvider[test-upstream]]"
        #expect(mapper.providerName == expectedName)
    }

    @Test func description() {
        let upstream = InMemoryProvider(name: "test-upstream", values: [:])
        let mapper = KeyMappingProvider(upstream: upstream) { key in key }
        let expectedDescription =
            "KeyMappingProvider[upstream: InMemoryProvider[test-upstream, 0 values]]"
        #expect(mapper.description == expectedDescription)
    }

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

        // Use a passtrhough mapper so the compat test can find the expected values
        let mapper = KeyMappingProvider(upstream: upstream) { $0 }
        try await ProviderCompatTest(provider: mapper).run()
    }
}
