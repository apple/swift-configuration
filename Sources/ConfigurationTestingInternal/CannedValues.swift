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
import Testing

/// A container for pre-defined test values that can be consumed sequentially.
///
/// ``CannedValues`` is useful for testing scenarios where you need to provide
/// a sequence of predetermined values to simulate different responses or states.
/// Values are consumed in FIFO (first-in, first-out) order.
///
/// ## Usage
///
/// Create a container with test values and consume them as needed:
///
/// ```swift
/// let cannedResponses = CannedValues(["first", "second", "third"])
///
/// let first = try cannedResponses.pop()  // "first"
/// let second = try cannedResponses.pop() // "second"
///
/// print(cannedResponses.values) // ["third"]
/// ```
package final class CannedValues<T: Sendable>: Sendable {

    /// Thread-safe storage for the remaining values.
    private let _values: Mutex<[T]>

    /// Creates a new container with the specified values.
    /// - Parameter values: The initial sequence of values to store.
    package init(_ values: [T]) {
        self._values = .init(values)
    }

    /// Removes and returns the first available value.
    ///
    /// Values are consumed in the order they were provided during initialization.
    ///
    /// - Returns: The next value in the sequence.
    /// - Throws: A test requirement failure if no more values remain.
    package func pop() throws -> T {
        try _values.withLock { values in
            try #require(!values.isEmpty)
            return values.removeFirst()
        }
    }

    /// The remaining unconsumed values.
    ///
    /// This property provides a snapshot of the current state without
    /// modifying the container.
    package var values: [T] {
        _values.withLock { $0 }
    }
}
