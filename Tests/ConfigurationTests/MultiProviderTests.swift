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
import Synchronization
import ConfigurationTestingInternal
import ConfigurationTesting

struct MultiProviderTests {

    @available(Configuration 1.0, *)
    var providers: [any ConfigProvider] {
        let first = InMemoryProvider(
            name: "first",
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
            ]
        )
        let second = InMemoryProvider(
            name: "second",
            values: [
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
        return [
            first,
            second,
        ]
    }

    /// A wrapper provider around the multi provider.
    ///
    /// This is not a generally useful wrapper - the multi provider is an internal implementation detail.
    ///
    /// Here in tests, it's just helpful to be able to run ProviderCompatTests on it.
    @available(Configuration 1.0, *)
    struct MultiProviderTestShims: ConfigProvider {

        /// The underlying multi provider.
        var multiProvider: MultiProvider

        var providerName: String { "MultiProvider" }

        func value(
            forKey key: AbsoluteConfigKey,
            type: ConfigType
        ) throws -> LookupResult {
            .init(encodedKey: "<not tested>", value: try multiProvider.value(forKey: key, type: type).1.get())
        }

        func fetchValue(
            forKey key: AbsoluteConfigKey,
            type: ConfigType
        ) async throws -> LookupResult {
            .init(
                encodedKey: "<not tested>",
                value: try await multiProvider.fetchValue(forKey: key, type: type).1.get()
            )
        }

        func watchValue<Return: ~Copyable>(
            forKey key: AbsoluteConfigKey,
            type: ConfigType,
            updatesHandler handler: (_ updates: ConfigUpdatesAsyncSequence<Result<LookupResult, any Error>, Never>)
                async throws ->
                Return
        ) async throws -> Return {
            try await multiProvider.watchValue(forKey: key, type: type) { updates in
                try await handler(
                    ConfigUpdatesAsyncSequence(
                        updates
                            .map { update in
                                update.1.map { .init(encodedKey: "<not tested>", value: $0) }
                            }
                    )
                )
            }
        }

        func snapshot() -> any ConfigSnapshot {
            multiProvider.snapshot()
        }

        func watchSnapshot<Return: ~Copyable>(
            updatesHandler: (_ updates: ConfigUpdatesAsyncSequence<any ConfigSnapshot, Never>) async throws -> Return
        )
            async throws -> Return
        {
            try await multiProvider.watchSnapshot { updates in
                try await updatesHandler(
                    ConfigUpdatesAsyncSequence(
                        updates.map { $0 }
                    )
                )
            }
        }
    }

    @available(Configuration 1.0, *)
    @Test func compat() async throws {
        let multiProvider = MultiProvider(providers: providers)
        try await ProviderCompatTest(provider: MultiProviderTestShims(multiProvider: multiProvider)).runTest()
    }

    @available(Configuration 1.0, *)
    @Test func watchingTwoUpstreams() async throws {
        let first = MutableInMemoryProvider(
            name: "first",
            initialValues: [
                "http.version": 2
            ]
        )
        let second = MutableInMemoryProvider(
            name: "second",
            initialValues: [
                "http.client.user-agent": "Config/1.0 (Test)"
            ]
        )
        let accessReporter = TestAccessReporter()
        let config = ConfigReader(providers: [first, second], accessReporter: accessReporter)

        try await withThrowingTaskGroup(of: Bool.self, returning: Void.self) { group in
            let future1 = TestFuture<String?>(name: "future1")
            let future2 = TestFuture<String?>(name: "future2")
            let future3 = TestFuture<String?>(name: "future3")
            group.addTask {
                try await config.watchString(forKey: "http.client.user-agent", default: "defaultUserAgent") { updates in
                    var iterator = updates.makeAsyncIterator()
                    future1.fulfill(try await iterator.next())
                    future2.fulfill(try await iterator.next())
                    future3.fulfill(try await iterator.next())
                    return true
                }
            }
            // Original value from second's initialValues.
            await #expect(future1.value == "Config/1.0 (Test)")
            // Updated value in second.
            second.setValue("anotherUserAgent", forKey: "http.client.user-agent")
            await #expect(future2.value == "anotherUserAgent")
            // Also set value in first (was nil before) - takes precedence.
            first.setValue("overrideUserAgent", forKey: "http.client.user-agent")
            await #expect(future3.value == "overrideUserAgent")
            try await #expect(group.next() == true)
        }

        #expect(accessReporter.events.count == 3)
    }

    @available(Configuration 1.0, *)
    @Test func watchingTwoUpstreams_handlerReturns() async throws {
        let first = InMemoryProvider(
            name: "first",
            values: [
                "value": "First"
            ]
        )
        let second = InMemoryProvider(
            name: "first",
            values: [
                "value": "Second"
            ]
        )
        let accessReporter = TestAccessReporter()
        let config = ConfigReader(providers: [first, second], accessReporter: accessReporter)

        try await config.watchString(forKey: "value", default: "default") { updates in
            var iterator = updates.makeAsyncIterator()
            let firstValue = try await iterator.next()
            #expect(firstValue == "First")
            // Return immediately
        }

        #expect(accessReporter.events.count == 1)
    }

    @available(Configuration 1.0, *)
    @Test func watchingTwoUpstreams_handlerThrowsError() async throws {
        let first = InMemoryProvider(
            name: "first",
            values: [
                "value": "First"
            ]
        )
        let second = InMemoryProvider(
            name: "first",
            values: [
                "value": "Second"
            ]
        )
        let accessReporter = TestAccessReporter()
        let config = ConfigReader(providers: [first, second], accessReporter: accessReporter)

        struct HandlerError: Error {}
        await #expect(throws: HandlerError.self) {
            try await config.watchString(forKey: "value", default: "default") { updates in
                var iterator = updates.makeAsyncIterator()
                let firstValue = try await iterator.next()
                #expect(firstValue == "First")
                // Throws immediately
                throw HandlerError()
            }
        }

        #expect(accessReporter.events.count == 1)
    }
}

@available(Configuration 1.0, *)
extension MultiSnapshot: ConfigSnapshot {
    var providerName: String {
        "MultiProvider"
    }

    func value(forKey key: AbsoluteConfigKey, type: ConfigType) throws -> LookupResult {
        .init(encodedKey: "<not tested>", value: try multiValue(forKey: key, type: type).1.get())
    }
}
