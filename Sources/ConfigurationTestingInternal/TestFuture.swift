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

/// A future implementation for testing asynchronous operations.
///
/// ``TestFuture`` provides a way to coordinate between test code that produces
/// a value asynchronously and test code that needs to wait for that value.
/// It's particularly useful for testing callback-based APIs and ensuring
/// proper sequencing in asynchronous tests.
///
/// ## Usage
///
/// Create a future, pass it to code that will fulfill it, then await the value:
///
/// ```swift
/// let future = TestFuture<String>()
///
/// // In some async operation
/// someAsyncOperation { result in
///     future.fulfill(result)
/// }
///
/// // In test code
/// let result = await future.value
/// ```
@available(Configuration 1.0, *)
package final class TestFuture<T: Sendable>: @unchecked Sendable /* mutex */ {

    /// The internal state of the future.
    private enum State {
        /// Waiting for fulfillment with stored continuations.
        case waitingForFulfillment([CheckedContinuation<T, Never>])
        /// The value has been delivered and is ready to be returned.
        case fulfilled(T)
    }

    /// The current state of the future.
    private let state: Mutex<State>

    /// Optional name for debugging and logging purposes.
    private let name: String?

    /// Source file where the future was created.
    private let file: StaticString

    /// Source line where the future was created.
    private let line: UInt

    /// Whether to enable verbose logging for debugging.
    private let verbose: Bool

    /// Creates a new unfulfilled future.
    /// - Parameters:
    ///   - name: Optional name for debugging purposes.
    ///   - verbose: Whether to enable verbose logging for debugging.
    ///   - file: Source file where the future is created (automatically captured).
    ///   - line: Source line where the future is created (automatically captured).
    package init(
        name: String? = nil,
        verbose: Bool = false,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        self.name = name
        self.verbose = verbose
        self.file = file
        self.line = line
        self.state = .init(.waitingForFulfillment([]))
    }

    /// Fulfills the future with the provided value.
    ///
    /// This method transitions the future from waiting to fulfilled state and
    /// resumes all waiting continuations with the provided value.
    ///
    /// - Parameter value: The value to fulfill the future with.
    ///
    /// - Precondition: The future must not have been fulfilled previously.
    ///   Calling this method multiple times will result in a fatal error.
    package func fulfill(_ value: T) {
        if verbose {
            print("Fulfilling \(name ?? "unnamed") at \(file):\(line) with \(value)")
        }
        let continuations: [CheckedContinuation<T, Never>] = state.withLock { state in
            switch state {
            case .fulfilled:
                fatalError("Fulfilled \(name ?? "unnamed") at \(file):\(line) twice")
            case .waitingForFulfillment(let continuations):
                if verbose {
                    print("Found \(continuations.count) waiting continuations for \(name ?? "unnamed")")
                }
                state = .fulfilled(value)
                return continuations
            }
        }
        if verbose {
            print("Resuming \(continuations.count) continuations for \(name ?? "unnamed")")
        }
        for continuation in continuations {
            continuation.resume(returning: value)
        }
        if verbose {
            print("All continuations resumed for \(name ?? "unnamed")")
        }
    }

    /// A result of getting the value from the internal storage.
    private enum GetValueResult {
        /// The value is not available yet, appended the caller's continuation to be resumed later.
        case appendedContinuation
        /// The value is already available, returning it right away.
        case returnValue(T)
    }

    /// The value stored by the future.
    ///
    /// This property suspends the current task if the future has not yet been
    /// fulfilled. Once ``fulfill(_:)`` is called, all waiting tasks will be
    /// resumed with the provided value.
    ///
    /// Multiple tasks can await the same future; they will all receive the
    /// same value when it becomes available.
    package var value: T {
        get async {
            if verbose {
                print("Getting value from \(name ?? "unnamed") at \(file):\(line)")
            }
            return await withCheckedContinuation { continuation in
                let result: GetValueResult = state.withLock { state in
                    switch state {
                    case .fulfilled(let value):
                        if verbose {
                            print("\(name ?? "unnamed") already fulfilled, returning immediately")
                        }
                        return .returnValue(value)
                    case .waitingForFulfillment(var continuations):
                        if verbose {
                            print(
                                "\(name ?? "unnamed") not fulfilled, adding continuation (total: \(continuations.count + 1))"
                            )
                        }
                        continuations.append(continuation)
                        state = .waitingForFulfillment(continuations)
                        return .appendedContinuation
                    }
                }
                switch result {
                case .appendedContinuation:
                    if verbose {
                        print("\(name ?? "unnamed") continuation stored, waiting for fulfill")
                    }
                    break
                case .returnValue(let value):
                    if verbose {
                        print("\(name ?? "unnamed") resuming continuation immediately with \(value)")
                    }
                    continuation.resume(returning: value)
                }
            }
        }
    }
}
