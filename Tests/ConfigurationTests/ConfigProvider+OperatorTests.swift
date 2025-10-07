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

struct ConfigProviderOperatorTests {
    @available(Configuration 1.0, *)
    @Test func prefixWithConfigKey() throws {
        let prefixed = InMemoryProvider(values: [["app", "foo"]: "bar"]).prefixKeys(with: ["app"])
        let result = try prefixed.value(forKey: ["foo"], type: .string)
        #expect(try result.value?.content.asString == "bar")
        #expect(result.encodedKey == "app.foo")
    }

    @available(Configuration 1.0, *)
    @Test func prefixWithString() throws {
        let prefixed = InMemoryProvider(values: [["app", "prod", "foo"]: "bar"]).prefixKeys(with: "app.prod")
        let result = try prefixed.value(forKey: ["foo"], type: .string)
        #expect(try result.value?.content.asString == "bar")
        #expect(result.encodedKey == "app.prod.foo")
    }

    @available(Configuration 1.0, *)
    @Test func mapKeys() throws {
        let mapped = InMemoryProvider(values: [["foo"]: "bar"])
            .mapKeys { key in
                switch key {
                case ["bar"]:
                    return ["foo"]
                case ["foo"]:
                    return ["not-foo"]
                default:
                    return key
                }
            }

        let result1 = try mapped.value(forKey: ["bar"], type: .string)
        #expect(try result1.value?.content.asString == "bar")
        #expect(result1.encodedKey == "foo")

        let result2 = try mapped.value(forKey: ["foo"], type: .string)
        #expect(result2.value == nil)
        #expect(result2.encodedKey == "not-foo")
    }
}
