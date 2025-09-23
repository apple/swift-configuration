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
import AsyncAlgorithms
@testable import Configuration

struct AsyncSequencesTests {

    enum TestError: Error, Equatable {
        case transformFailed
        case upstreamFailed
    }

    // MARK: - ConfigUpdatesAsyncSequence tests

    @Test func updatesAsyncSequenceWrapsExistentialSequence() async throws {
        let values = [1, 2, 3, 4, 5]
        let updatesSequence = ConfigUpdatesAsyncSequence(values.async)
        let results = await updatesSequence.collect()
        #expect(results == values)
    }

    @Test func updatesAsyncSequenceWithEmptySequence() async throws {
        let updatesSequence = ConfigUpdatesAsyncSequence(([] as [Int]).async)
        let results = await updatesSequence.collect()
        #expect(results.isEmpty)
    }

    @Test func updatesAsyncSequencePropagatesErrors() async throws {
        let throwingSequence = AsyncThrowingStream<Int, any Error> { continuation in
            continuation.yield(1)
            continuation.yield(2)
            continuation.finish(throwing: TestError.upstreamFailed)
        }
        let updatesSequence = ConfigUpdatesAsyncSequence(throwingSequence)

        var results: [Int] = []
        let error = await #expect(throws: TestError.self) {
            for try await value in updatesSequence {
                results.append(value)
            }
        }
        #expect(error == .upstreamFailed)
        #expect(results == [1, 2])
    }

    // MARK: - ConcreteAsyncSequence tests

    @Test func concreteAsyncSequenceWrapsExistentialSequence() async throws {
        let values = [1, 2, 3, 4, 5]
        let concreteSequence = ConcreteAsyncSequence(values.async)
        let results = await concreteSequence.collect()
        #expect(results == values)
    }

    @Test func concreteAsyncSequenceWithEmptySequence() async throws {
        let concreteSequence = ConcreteAsyncSequence(([] as [Int]).async)
        let results = await concreteSequence.collect()
        #expect(results.isEmpty)
    }

    @Test func concreteAsyncSequencePropagatesErrors() async throws {
        let throwingSequence = AsyncThrowingStream<Int, any Error> { continuation in
            continuation.yield(1)
            continuation.yield(2)
            continuation.finish(throwing: TestError.upstreamFailed)
        }
        let concreteSequence = ConcreteAsyncSequence(throwingSequence)

        var results: [Int] = []
        let error = await #expect(throws: TestError.self) {
            for try await value in concreteSequence {
                results.append(value)
            }
        }
        #expect(error == .upstreamFailed)
        #expect(results == [1, 2])
    }

    // MARK: - mapThrowing Tests

    @Test func mapThrowingSuccessfulTransformation() async throws {
        let values = [1, 2, 3]
        let asyncSequence = values.async
        let mappedSequence = asyncSequence.mapThrowing { value -> String in
            "Value: \(value)"
        }

        let results = await mappedSequence.collect()
        let expected = ["Value: 1", "Value: 2", "Value: 3"]
        #expect(results == expected)
    }

    @Test func mapThrowingWithEmptySequence() async throws {
        let emptySequence = ([] as [Int]).async
        let mappedSequence = emptySequence.mapThrowing { value -> String in
            "Value: \(value)"
        }

        let results = await mappedSequence.collect()
        #expect(results.isEmpty)
    }

    @Test func mapThrowingPropagatesTransformErrors() async throws {
        let asyncSequence = [1, 2, 3, 4, 5].async
        let mappedSequence = asyncSequence.mapThrowing { value -> String in
            if value == 3 {
                throw TestError.transformFailed
            }
            return "Value: \(value)"
        }

        var results: [String] = []
        let error = await #expect(throws: TestError.self) {
            for try await value in mappedSequence {
                results.append(value)
            }
        }
        #expect(error == .transformFailed)
        #expect(results == ["Value: 1", "Value: 2"])
    }
}

// MARK: - Test Utilities

extension AsyncSequence where Failure == Never {
    /// Collects all elements from the async sequence into an array.
    ///
    /// This method iterates through the entire async sequence and accumulates
    /// all elements into an array, which is returned once the sequence completes.
    /// This is useful for testing async sequences where you need to verify
    /// all emitted values.
    ///
    /// - Returns: An array containing all elements from the async sequence.
    func collect() async -> [Element] {
        var results: [Element] = []
        for await element in self {
            results.append(element)
        }
        return results
    }
}

extension AsyncSequence {
    /// Collects all elements from the async sequence into an array.
    ///
    /// This method iterates through the entire async sequence and accumulates
    /// all elements into an array, which is returned once the sequence completes.
    /// This is useful for testing async sequences where you need to verify
    /// all emitted values.
    ///
    /// - Returns: An array containing all elements from the async sequence.
    /// - Throws: Any error thrown by the async sequence during iteration.
    func collect() async throws -> [Element] {
        var results: [Element] = []
        for try await element in self {
            results.append(element)
        }
        return results
    }
}
