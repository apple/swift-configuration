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
import ConfigurationTestingInternal

struct ConfigReaderTests {
    @available(Configuration 1.0, *)
    @Test func create() throws {
        let config = ConfigReader(provider: InMemoryProvider(values: [:])).scoped(to: "foo")
        // This config has no providers, so every returned value will match the default.
        try #require(config.string(forKey: "bar", default: "test") == "test")
    }

    @available(Configuration 1.0, *)
    @Test func scoping() throws {
        let provider = InMemoryProvider(
            name: "test",
            values: [
                "http.client.user-agent": "Config/1.0 (Test)"
            ]
        )
        let top = ConfigReader(provider: provider)
        #expect(top.string(forKey: "user-agent") == nil)
        let scoped = top.scoped(to: "http.client")
        #expect(scoped.string(forKey: "user-agent") == "Config/1.0 (Test)")
    }

    @available(Configuration 1.0, *)
    @Test func context() throws {
        let provider = InMemoryProvider(values: [
            AbsoluteConfigKey(["http", "client", "timeout"], context: ["upstream": "example1.org"]): 15.0,
            AbsoluteConfigKey(["http", "client", "timeout"], context: ["upstream": "example2.org"]): 30.0,
        ])
        let config = ConfigReader(provider: provider)
        #expect(config.double(forKey: "http.client.timeout") == nil)
        #expect(config.double(forKey: ConfigKey("http.client.timeout", context: ["upstream": "example1.org"])) == 15.0)
        #expect(config.double(forKey: ConfigKey("http.client.timeout", context: ["upstream": "example2.org"])) == 30.0)
    }

    enum TestEnum: String, Equatable {
        case one
        case two
    }

    struct TestStringConvertible: ExpressibleByConfigString, Equatable {
        var string: String
        init(string: String) {
            self.string = string
        }
        var description: String {
            string
        }
        init?(configString: String) {
            self.string = configString
        }

        static var hello: Self {
            .init(string: "Hello")
        }

        static var world: Self {
            .init(string: "World")
        }
    }

    enum TestIntEnum: Int, Equatable {
        case zero
        case one
    }

    struct TestIntConvertible: ExpressibleByConfigInt, Equatable {
        var integer: Int
        var description: String {
            "\(integer)"
        }
        init?(configInt: Int) {
            self.integer = configInt
        }
        static var zero: Self {
            .init(configInt: 0)!
        }
        static var one: Self {
            .init(configInt: 1)!
        }
    }

    enum Defaults {
        static var string: String { "Hello" }
        static var otherString: String { "Other Hello" }
        static var int: Int { 42 }
        static var otherInt: Int { 24 }
        static var double: Double { 3.14 }
        static var otherDouble: Double { 2.72 }
        static var bool: Bool { true }
        static var otherBool: Bool { false }
        static var bytes: [UInt8] { .magic }
        static var otherBytes: [UInt8] { .magic2 }
        static var stringArray: [String] { ["Hello", "World"] }
        static var otherStringArray: [String] { ["Hello", "Swift"] }
        static var intArray: [Int] { [42, 24] }
        static var otherIntArray: [Int] { [16, 32] }
        static var doubleArray: [Double] { [3.14, 2.72] }
        static var otherDoubleArray: [Double] { [0.9, 1.8] }
        static var boolArray: [Bool] { [true, false] }
        static var otherBoolArray: [Bool] { [false, true, true] }
        static var byteChunkArray: [[UInt8]] { [.magic, .magic2] }
        static var otherByteChunkArray: [[UInt8]] { [.magic, .magic2, .magic] }
        static var stringEnum: TestEnum { .one }
        static var otherStringEnum: TestEnum { .two }
        static var stringConvertible: TestStringConvertible { .hello }
        static var otherStringConvertible: TestStringConvertible { .world }
        static var stringEnumArray: [TestEnum] { [.one, .two] }
        static var otherStringEnumArray: [TestEnum] { [.one, .two, .one] }
        static var stringConvertibleArray: [TestStringConvertible] { [.hello, .world] }
        static var otherStringConvertibleArray: [TestStringConvertible] { [.hello, .world, .hello] }
        static var intEnum: TestIntEnum { .zero }
        static var otherIntEnum: TestEnum { .one }
        static var intConvertible: TestIntConvertible { .zero }
        static var otherIntConvertible: TestIntConvertible { .zero }
        static var intEnumArray: [TestIntEnum] { [.zero, .one] }
        static var otherIntEnumArray: [TestIntEnum] { [.zero, .one, .zero] }
        static var intConvertibleArray: [TestIntConvertible] { [.zero, .one] }
        static var otherIntConvertibleArray: [TestIntConvertible] { [.zero, .one, .zero] }
    }

    @available(Configuration 1.0, *)
    static var provider: TestProvider {
        TestProvider(values: [
            "string": .success(ConfigValue(Defaults.string, isSecret: false)),
            "int": .success(ConfigValue(Defaults.int, isSecret: false)),
            "double": .success(ConfigValue(Defaults.double, isSecret: false)),
            "bool": .success(ConfigValue(Defaults.bool, isSecret: false)),
            "bytes": .success(ConfigValue(Defaults.bytes, isSecret: false)),
            "stringArray": .success(ConfigValue(Defaults.stringArray, isSecret: false)),
            "intArray": .success(ConfigValue(Defaults.intArray, isSecret: false)),
            "doubleArray": .success(ConfigValue(Defaults.doubleArray, isSecret: false)),
            "boolArray": .success(ConfigValue(Defaults.boolArray, isSecret: false)),
            "byteChunkArray": .success(ConfigValue(Defaults.byteChunkArray, isSecret: false)),

            "stringEnum": .success(ConfigValue(Defaults.stringEnum.rawValue, isSecret: false)),
            "stringConvertible": .success(ConfigValue(Defaults.stringConvertible.description, isSecret: false)),
            "stringEnumArray": .success(ConfigValue(Defaults.stringEnumArray.map(\.rawValue), isSecret: false)),
            "stringConvertibleArray": .success(
                ConfigValue(Defaults.stringConvertibleArray.map(\.description), isSecret: false)
            ),
            "intEnum": .success(ConfigValue(Defaults.intEnum.rawValue, isSecret: false)),
            "intConvertible": .success(ConfigValue(Defaults.intConvertible.description, isSecret: false)),
            "intEnumArray": .success(ConfigValue(Defaults.intEnumArray.map(\.rawValue), isSecret: false)),
            "intConvertibleArray": .success(
                ConfigValue(Defaults.intConvertibleArray.map(\.description), isSecret: false)
            ),
            "failure": .failure(TestProvider.TestError()),
        ])
    }

    @available(Configuration 1.0, *)
    static var config: ConfigReader {
        ConfigReader(provider: provider)
    }
}
