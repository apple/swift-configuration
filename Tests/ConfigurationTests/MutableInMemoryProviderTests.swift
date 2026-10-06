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
import ConfigurationTesting

struct MutableInMemoryProviderTests {

    @available(Configuration 1.0, *)
    func makeProvider() -> MutableInMemoryProvider {
        MutableInMemoryProvider(
            name: "test",
            initialValues: [
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
    }

    @available(Configuration 1.0, *)
    @Test func printingDescription() throws {
        let expectedDescription = #"""
            MutableInMemoryProvider[test, 0 watchers, 20 values]
            """#
        let provider = makeProvider()
        #expect(provider.description == expectedDescription)
    }

    @available(Configuration 1.0, *)
    @Test func printingDebugDescription() throws {
        let expectedDebugDescription = #"""
            MutableInMemoryProvider[test, 0 watchers, 20 values: bool=[bool: true], booly.array=[boolArray: true, false], byteChunky.array=[byteChunkArray: 5 bytes, prefix: 6d61676963, 6 bytes, prefix: 6d6167696332], bytes=[bytes: 5 bytes, prefix: 6d61676963], double=[double: 3.14], doubly.array=[doubleArray: 3.14, 2.72], int=[int: 42], inty.array=[intArray: 42, 24], other.bool=[bool: false], other.booly.array=[boolArray: false, true, true], other.byteChunky.array=[byteChunkArray: 5 bytes, prefix: 6d61676963, 6 bytes, prefix: 6d6167696332, 5 bytes, prefix: 6d61676963], other.bytes=[bytes: 6 bytes, prefix: 6d6167696332], other.double=[double: 2.72], other.doubly.array=[doubleArray: 0.9, 1.8], other.int=[int: 24], other.inty.array=[intArray: 16, 32], other.string=[string: Other Hello], other.stringy.array=[stringArray: Hello, Swift], string=[string: Hello], stringy.array=[stringArray: Hello, World]]
            """#
        let provider = makeProvider()
        #expect(provider.debugDescription == expectedDebugDescription)
    }

    @available(Configuration 1.0, *)
    @Test func compat() async throws {
        let provider = makeProvider()
        try await ProviderCompatTest(provider: provider).runTest()
    }

    @available(Configuration 1.0, *)
    @Test func mutatingGet() throws {
        let provider = makeProvider()
        let config = ConfigReader(provider: provider)

        #expect(config.bool(forKey: "bool") == true)
        provider.setValue(false, forKey: "bool")
        #expect(config.bool(forKey: "bool") == false)
    }

    @available(Configuration 1.0, *)
    @Test func mutatingFetch() async throws {
        let provider = makeProvider()
        let config = ConfigReader(provider: provider)

        try await #expect(config.fetchBool(forKey: "bool") == true)
        provider.setValue(false, forKey: "bool")
        try await #expect(config.fetchBool(forKey: "bool") == false)
    }

    @available(Configuration 1.0, *)
    @Test func mutatingWatch() async throws {
        let provider = makeProvider()
        let config = ConfigReader(provider: provider)

        #expect(
            try await config.watchBool(
                forKey: "bool",
                updatesHandler: { await $0.first }
            ) == .some(true)
        )
        provider.setValue(false, forKey: "bool")
        #expect(
            try await config.watchBool(
                forKey: "bool",
                updatesHandler: { await $0.first }
            ) == .some(false)
        )

        let firstValueFuture = TestFuture<Bool??>(name: "firstValue")
        let secondValueFuture = TestFuture<Bool??>(name: "secondValue")
        await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await config.watchBool(forKey: "bool") { updates in
                    var iterator = updates.makeAsyncIterator()
                    firstValueFuture.fulfill(try await iterator.next())
                    secondValueFuture.fulfill(try await iterator.next())
                }
            }
            await #expect(firstValueFuture.value == false)
            provider.setValue(true, forKey: "bool")
            await #expect(secondValueFuture.value == true)
        }
    }

    @available(Configuration 1.0, *)
    @Test func mutatingGetSnapshot() throws {
        let provider = makeProvider()
        let config = ConfigReader(provider: provider)

        let snapshot = config.snapshot()
        #expect(snapshot.bool(forKey: "bool") == true)
        provider.setValue(false, forKey: "bool")
        #expect(snapshot.bool(forKey: "bool") == true)

        #expect(config.bool(forKey: "bool") == false)
    }

    @available(Configuration 1.0, *)
    @Test func mutatingWatchSnapshot() async throws {
        let provider = makeProvider()
        let config = ConfigReader(provider: provider)

        let firstValueFuture = TestFuture<Bool??>(name: "firstValue")
        let firstValueAfterFuture = TestFuture<Bool??>(name: "firstValueAfter")
        let secondValueFuture = TestFuture<Bool??>(name: "secondValue")
        await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await config.watchSnapshot { updates in
                    var iterator = updates.makeAsyncIterator()
                    let firstSnapshot = try await iterator.next()
                    firstValueFuture.fulfill(firstSnapshot?.bool(forKey: "bool"))
                    let secondSnapshot = try await iterator.next()
                    firstValueAfterFuture.fulfill(firstSnapshot?.bool(forKey: "bool"))
                    secondValueFuture.fulfill(secondSnapshot?.bool(forKey: "bool"))
                }
            }
            await #expect(firstValueFuture.value == true)
            provider.setValue(false, forKey: "bool")
            await #expect(firstValueAfterFuture.value == true)
            await #expect(secondValueFuture.value == false)
        }
    }

    @available(Configuration 1.0, *)
    @Test func batchMutatingGet() throws {
        let provider = makeProvider()
        let config = ConfigReader(provider: provider)

        provider.setValues([
            "string": "Bye",
            "int": 43,
            "bool": nil,
        ])
        #expect(config.string(forKey: "string") == "Bye")
        #expect(config.int(forKey: "int") == 43)
        #expect(config.bool(forKey: "bool") == nil)
        #expect(config.double(forKey: "double") == 3.14)
    }

    @available(Configuration 1.0, *)
    @Test func batchMutatingWatch() async throws {
        let provider = makeProvider()
        let config = ConfigReader(provider: provider)

        let firstValueFuture = TestFuture<Bool??>(name: "firstValue")
        let secondValueFuture = TestFuture<Bool??>(name: "secondValue")
        await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await config.watchBool(forKey: "bool") { updates in
                    var iterator = updates.makeAsyncIterator()
                    firstValueFuture.fulfill(try await iterator.next())
                    secondValueFuture.fulfill(try await iterator.next())
                }
            }
            await #expect(firstValueFuture.value == true)
            provider.setValues(["bool": false, "int": 43])
            await #expect(secondValueFuture.value == false)
        }
    }

    @available(Configuration 1.0, *)
    @Test func batchMutatingWatchSnapshot() async throws {
        let provider = makeProvider()
        let config = ConfigReader(provider: provider)

        let firstSnapshotConsumed = TestFuture<Void>(name: "firstSnapshotConsumed")
        let secondStringFuture = TestFuture<String?>(name: "secondString")
        let secondIntFuture = TestFuture<Int?>(name: "secondInt")
        await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await config.watchSnapshot { updates in
                    var iterator = updates.makeAsyncIterator()
                    _ = try await iterator.next()
                    firstSnapshotConsumed.fulfill(())
                    let secondSnapshot = try await iterator.next()
                    secondStringFuture.fulfill(secondSnapshot?.string(forKey: "string"))
                    secondIntFuture.fulfill(secondSnapshot?.int(forKey: "int"))
                }
            }
            _ = await firstSnapshotConsumed.value
            provider.setValues(["string": "Bye", "int": 43])
            await #expect(secondStringFuture.value == "Bye")
            await #expect(secondIntFuture.value == 43)
        }
    }

    @available(Configuration 1.0, *)
    @Test func withValuesReadModifyWrite() async throws {
        let provider = MutableInMemoryProvider(initialValues: ["count": 0])
        let config = ConfigReader(provider: provider)

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<1000 {
                group.addTask {
                    provider.withValues { values in
                        let count = (try? values["count"]?.content.asInt) ?? 0
                        values["count"] = .init(.int(count + 1), isSecret: false)
                    }
                }
            }
        }
        #expect(config.int(forKey: "count") == 1000)
    }

    @available(Configuration 1.0, *)
    @Test func withValuesReturnsNonCopyableValue() {
        let provider = makeProvider()

        let count = provider.withValues { values in
            NonCopyableCount(value: values.count)
        }
        #expect(count.value == 20)
    }

    @available(Configuration 1.0, *)
    @Test func withValuesWatchSnapshot() async throws {
        let provider = makeProvider()
        let config = ConfigReader(provider: provider)

        let firstSnapshotConsumed = TestFuture<Void>(name: "firstSnapshotConsumed")
        let secondStringFuture = TestFuture<String?>(name: "secondString")
        let secondIntFuture = TestFuture<Int?>(name: "secondInt")
        await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await config.watchSnapshot { updates in
                    var iterator = updates.makeAsyncIterator()
                    _ = try await iterator.next()
                    firstSnapshotConsumed.fulfill(())
                    let secondSnapshot = try await iterator.next()
                    secondStringFuture.fulfill(secondSnapshot?.string(forKey: "string"))
                    secondIntFuture.fulfill(secondSnapshot?.int(forKey: "int"))
                }
            }
            _ = await firstSnapshotConsumed.value
            provider.withValues { values in
                values["string"] = "Bye"
                values["int"] = 43
            }
            await #expect(secondStringFuture.value == "Bye")
            await #expect(secondIntFuture.value == 43)
        }
    }

    @available(Configuration 1.0, *)
    @Test func withValuesThrowingKeepsChanges() async throws {
        struct TestError: Error {}
        let provider = makeProvider()
        let config = ConfigReader(provider: provider)

        let firstValueFuture = TestFuture<Bool??>(name: "firstValue")
        let secondValueFuture = TestFuture<Bool??>(name: "secondValue")
        await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await config.watchBool(forKey: "bool") { updates in
                    var iterator = updates.makeAsyncIterator()
                    firstValueFuture.fulfill(try await iterator.next())
                    secondValueFuture.fulfill(try await iterator.next())
                }
            }
            await #expect(firstValueFuture.value == true)
            #expect(throws: TestError.self) {
                try provider.withValues { values in
                    values["bool"] = false
                    throw TestError()
                }
            }
            await #expect(secondValueFuture.value == false)
        }
        #expect(config.bool(forKey: "bool") == false)
    }
}

/// A value that can't be copied, to check that `withValues` can return one.
private struct NonCopyableCount: ~Copyable {
    var value: Int
}
