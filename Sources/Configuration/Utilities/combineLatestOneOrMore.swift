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

import Synchronization

/// A container that maintains the latest values from multiple async sequences.
///
/// This class coordinates the "combine latest" operation by storing the most recent
/// value from each source sequence and emitting combined arrays only when all sources
/// have produced at least one value.
@available(Configuration 1.0, *)
private final class Combiner<Element: Sendable>: Sendable {

    /// The internal state.
    private struct State {
        /// The current elements.
        var elements: [Element?]
    }

    /// The underlying mutex-protected storage.
    private let storage: Mutex<State>

    /// The continuation where to send values.
    private let continuation: AsyncStream<[Element]>.Continuation

    /// The stream of combined arrays of elements.
    let stream: AsyncStream<[Element]>

    /// Creates a new combiner for the specified number of async sequences.
    ///
    /// - Parameter count: The number of async sequences to combine. Must be at least 1.
    /// - Precondition: `count >= 1`
    init(count: Int) {
        precondition(count >= 1, "Combiner requires the count of 1 or more")
        self.storage = .init(
            .init(elements: Array(repeating: nil, count: count))
        )
        (self.stream, self.continuation) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(1))
    }

    /// Updates the value from a specific async sequence and emits a combined array if ready.
    ///
    /// This method atomically updates the value at the specified index and checks if
    /// all sequences have produced at least one value. If so, it emits the current
    /// snapshot of all latest values.
    ///
    /// - Parameters:
    ///   - value: The new value from the async sequence.
    ///   - index: The index of the async sequence that produced this value.
    func updateValue(_ value: Element, at index: Int) {
        let valueToEmit: [Element]? = storage.withLock { state in
            state.elements[index] = value
            let nonNilValues = state.elements.compactMap { $0 }
            if nonNilValues.count == state.elements.count {
                // All values have been emitted at least once, and something changed.
                // Emit the latest snapshot now.
                return nonNilValues
            } else {
                // Not all upstreams have emitted a value yet, don't emit a snapshot yet.
                return nil
            }
        }
        if let valueToEmit {
            continuation.yield(valueToEmit)
        }
    }
}

/// Combines multiple async sequences using a "combine latest" strategy.
///
/// This function takes multiple async sequences and combines their latest values into
/// arrays. It only emits a combined array after all sequences have produced at least
/// one value, and then emits a new array whenever any sequence produces a new value.
///
/// ## Behavior
///
/// - **Initial emission**: No values are emitted until all sequences have produced at least one value
/// - **Subsequent emissions**: A new combined array is emitted whenever any sequence produces a new value
/// - **Order preservation**: Values in the combined arrays maintain the same order as the input sequences
/// - **Latest values**: Only the most recent value from each sequence is included in each emission
///
/// ## Concurrency
///
/// All input sequences are processed concurrently using a task group. If any sequence
/// throws an error or completes unexpectedly, the entire operation is cancelled.
///
/// - Parameters:
///   - elementType: The type of elements in the input async sequences.
///   - sources: An array of closures that each iterate over an async sequence.
///   - updatesHandler: A closure that processes the combined sequence of arrays.
/// - Throws: When any source throws, when the handler throws, or when cancelled.
/// - Returns: The value returned by the handler.
/// - Precondition: `sources` must not be empty.
@available(Configuration 1.0, *)
func combineLatestOneOrMore<Element: Sendable, Return>(
    elementType: Element.Type = Element.self,
    sources: [@Sendable ((ConfigUpdatesAsyncSequence<Element, Never>) async throws -> Void) async throws -> Void],
    updatesHandler: (ConfigUpdatesAsyncSequence<[Element], Never>) async throws -> Return
) async throws -> Return {
    precondition(!sources.isEmpty, "combineLatestTwoOrMore requires at least one source")
    let combiner = Combiner<Element>(count: sources.count)
    return try await withThrowingTaskGroup(of: Void.self, returning: Return.self) { group in
        for (index, source) in sources.enumerated() {
            group.addTask {
                try await source { updates in
                    for await element in updates {
                        combiner.updateValue(element, at: index)
                    }
                }
                // TODO: Is this the right error to throw when a source returns prematurely?
                throw CancellationError()
            }
        }
        defer {
            group.cancelAll()
        }
        return try await updatesHandler(.init(combiner.stream))
    }
}
