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
public import Configuration
import ConfigurationTestingInternal

/// A comprehensive test suite for validating `ConfigProvider` implementations.
///
/// This test suite verifies that configuration providers correctly implement all required
/// functionality including synchronous and asynchronous value retrieval, snapshot operations,
/// and value watching capabilities.
///
/// ## Usage
///
/// Create a test instance with your provider and run the compatibility tests:
///
/// ```swift
/// let provider = MyCustomProvider()
/// let test = ProviderCompatTest(provider: provider)
/// try await test.run()
/// ```
///
/// ## Required Test Data
///
/// The provider under test must be populated with specific test values to ensure
/// comprehensive validation. The required configuration data includes:
///
/// ```swift
/// [
///     "string": String("Hello"),
///     "other.string": String("Other Hello"),
///     "int": Int(42),
///     "other.int": Int(24),
///     "double": Double(3.14),
///     "other.double": Double(2.72),
///     "bool": Bool(true),
///     "other.bool": Bool(false),
///     "bytes": [UInt8](.magic),
///     "other.bytes": [UInt8](.magic2),
///     "stringy.array": [String](["Hello", "World"]),
///     "other.stringy.array": [String](["Hello", "Swift"]),
///     "inty.array": [Int]([42, 24]),
///     "other.inty.array": [Int]([16, 32]),
///     "doubly.array": [Double]([3.14, 2.72]),
///     "other.doubly.array": [Double]([0.9, 1.8]),
///     "booly.array": [Bool]([true, false]),
///     "other.booly.array": [Bool]([false, true, true]),
///     "byteChunky.array": [[UInt8]]([.magic, .magic2]),
///     "other.byteChunky.array": [[UInt8]]([.magic, .magic2, .magic]),
/// ]
/// ```
public struct ProviderCompatTest: Sendable {

    /// Configuration options for customizing test behavior.
    public struct TestConfiguration: Sendable {

        /// Value overrides for testing custom scenarios.
        ///
        /// Use this to test how your provider handles different values than the standard
        /// test dataset. Keys should match the dot-separated format used in the test data.
        public var overrides: [String: ConfigContent]

        /// Creates a new test configuration.
        /// - Parameter overrides: Custom values to use instead of default test values.
        public init(overrides: [String: ConfigContent] = [:]) {
            self.overrides = overrides
        }
    }

    /// The provider under test.
    private let provider: any ConfigProvider

    /// Configuration of the compat test.
    private let configuration: TestConfiguration

    /// Creates a new compatibility test suite.
    /// - Parameters:
    ///   - provider: The configuration provider to test.
    ///   - configuration: Test configuration options.
    public init(provider: any ConfigProvider, configuration: TestConfiguration = .init()) {
        self.provider = provider
        self.configuration = configuration
    }

    /// Executes the complete compatibility test suite.
    ///
    /// This method runs all provider compatibility tests including:
    /// - Synchronous value retrieval (`getValue()`)
    /// - Asynchronous value fetching (`fetchValue()`)
    /// - Value watching capabilities (`watchValue()`)
    /// - Snapshot operations (`getSnapshot()`)
    /// - Snapshot watching (`watchSnapshot()`)
    ///
    /// - Throws: Test failures or provider errors encountered during testing.
    public func run() async throws {
        try value()
        try await fetchValue()
        try await watchValue()
        try snapshot()
        try await watchSnapshot()
    }

    let keyDecoder = SeparatorKeyDecoder.dotSeparated
    let expectedValues: [(String, ConfigType, ConfigContent?)] = [
        ("string", .string, .string("Hello")),
        ("absent.string", .string, nil),
        ("other.string", .string, .string("Other Hello")),
        ("int", .int, .int(42)),
        ("absent.int", .int, nil),
        ("other.int", .int, .int(24)),
        ("double", .double, .double(3.14)),
        ("absent.double", .double, nil),
        ("other.double", .double, .double(2.72)),
        ("bool", .bool, .bool(true)),
        ("absent.bool", .bool, nil),
        ("other.bool", .bool, .bool(false)),
        ("bytes", .bytes, .bytes(.magic)),
        ("absent.bytes", .bytes, nil),
        ("other.bytes", .bytes, .bytes(.magic2)),
        ("stringy.array", .stringArray, .stringArray(["Hello", "World"])),
        ("absent.string.array", .stringArray, nil),
        ("other.stringy.array", .stringArray, .stringArray(["Hello", "Swift"])),
        ("inty.array", .intArray, .intArray([42, 24])),
        ("absent.int.array", .intArray, nil),
        ("other.inty.array", .intArray, .intArray([16, 32])),
        ("doubly.array", .doubleArray, .doubleArray([3.14, 2.72])),
        ("absent.double.array", .doubleArray, nil),
        ("other.doubly.array", .doubleArray, .doubleArray([0.9, 1.8])),
        ("booly.array", .boolArray, .boolArray([true, false])),
        ("absent.bool.array", .boolArray, nil),
        ("other.booly.array", .boolArray, .boolArray([false, true, true])),
        ("byteChunky.array", .byteChunkArray, .byteChunkArray([.magic, .magic2])),
        ("absent.byteChunk.array", .byteChunkArray, nil),
        ("other.byteChunky.array", .byteChunkArray, .byteChunkArray([.magic, .magic2, .magic])),
    ]
}

extension ProviderCompatTest {

    private func value() throws {
        let provider = self.provider
        for (key, type, content) in expectedValues {
            let value = try provider.value(forKey: .init(keyDecoder.decode(key, context: [:])), type: type)
            let resolvedContent = configuration.overrides[key] ?? content
            #expect(value.value?.content == resolvedContent, "Op: \(#function), key: \(key), type: \(type)")
        }
    }

    private func fetchValue() async throws {
        let provider = self.provider
        for (key, type, content) in expectedValues {
            let value = try await provider.fetchValue(forKey: .init(keyDecoder.decode(key, context: [:])), type: type)
            let resolvedContent = configuration.overrides[key] ?? content
            #expect(value.value?.content == resolvedContent, "Op: \(#function), key: \(key), type: \(type)")
        }
    }

    private func watchValue() async throws {
        let provider = self.provider
        for (key, type, content) in expectedValues {
            let resolvedContent = configuration.overrides[key] ?? content
            let valueFuture = TestFuture<ConfigValue?>()
            try await provider.watchValue(forKey: .init(keyDecoder.decode(key, context: [:])), type: type) {
                try valueFuture.fulfill(await $0.first?.get().value)
            }
            #expect(await valueFuture.value?.content == resolvedContent, "Op: \(#function), key: \(key), type: \(type)")
        }
    }

    private func snapshot() throws {
        let provider = self.provider
        let snapshot = provider.snapshot()
        for (key, type, content) in expectedValues {
            let value = try snapshot.value(forKey: .init(keyDecoder.decode(key, context: [:])), type: type)
            let resolvedContent = configuration.overrides[key] ?? content
            #expect(value.value?.content == resolvedContent, "Op: \(#function), key: \(key), type: \(type)")
        }
    }

    private func watchSnapshot() async throws {
        let provider = self.provider
        try await provider.watchSnapshot { updates in
            for try await snapshot in updates {
                for (key, type, content) in expectedValues {
                    let value = try snapshot.value(forKey: .init(keyDecoder.decode(key, context: [:])), type: type)
                    let resolvedContent = configuration.overrides[key] ?? content
                    #expect(value.value?.content == resolvedContent, "Op: \(#function), key: \(key), type: \(type)")
                }
                break
            }
        }
    }
}
