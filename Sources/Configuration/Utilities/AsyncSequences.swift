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

/// A concrete async sequence for delivering updated configuration values.
@available(Configuration 1.0, *)
public struct ConfigUpdatesAsyncSequence<Element: Sendable, Failure: Error> {

    /// The upstream async sequence that this concrete sequence wraps.
    ///
    /// This property holds the async sequence that provides the actual elements.
    /// All operations on this concrete sequence are delegated to this upstream sequence.
    private let upstream: any AsyncSequence<Element, Failure>

    /// Creates a new concrete async sequence wrapping the provided existential sequence.
    ///
    /// - Parameter upstream: The async sequence to wrap.
    public init(_ upstream: some AsyncSequence<Element, Failure>) {
        self.upstream = upstream
    }
}

@available(Configuration 1.0, *)
extension ConfigUpdatesAsyncSequence: AsyncSequence {

    /// An async iterator that wraps an existential async iterator.
    ///
    /// This iterator provides the concrete implementation for iterating over
    /// the wrapped existential async sequence. It delegates all operations
    /// to the upstream iterator while maintaining type safety.
    struct Iterator: AsyncIteratorProtocol {

        /// The upstream async iterator that provides the actual iteration logic.
        var upstream: any AsyncIteratorProtocol<Element, Failure>

        // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
        mutating func next(
            isolation actor: isolated (any Actor)?
        ) async throws(Failure) -> Element? {
            try await upstream.next(isolation: actor)
        }
    }

    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public func makeAsyncIterator() -> some AsyncIteratorProtocol<Element, Failure> {
        Iterator(upstream: upstream.makeAsyncIterator())
    }
}

// MARK: - AsyncSequence extensions

@available(Configuration 1.0, *)
extension AsyncSequence where Failure == Never {

    /// Maps each element of the sequence using a throwing transform, introducing a failure type.
    ///
    /// This method allows you to transform elements of a non-throwing async sequence
    /// using a transform that can throw errors. The resulting sequence will have
    /// the specified failure type.
    ///
    /// - Parameter transform: A throwing closure that transforms each element.
    /// - Returns: An async sequence that produces transformed elements and can throw errors of type `Failure`.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let numbers = AsyncStream { continuation in
    ///     for i in 1...5 {
    ///         continuation.yield(i)
    ///     }
    ///     continuation.finish()
    /// }
    ///
    /// let strings = numbers.mapThrowing { number in
    ///     guard number > 0 else {
    ///         throw ValidationError.invalidNumber
    ///     }
    ///     return String(number)
    /// }
    /// ```
    func mapThrowing<NewValue, Failure: Error>(
        _ transform: @escaping (Element) throws(Failure) -> NewValue
    ) -> some AsyncSequence<NewValue, Failure> {
        MapThrowingAsyncSequence(upstream: self, transform: transform)
    }
}

// MARK: - MapThrowingAsyncSequence

/// An async sequence that transforms elements using a throwing closure.
///
/// This type provides a concrete implementation for mapping over async sequences
/// where the transform function can throw errors. It converts a non-throwing
/// async sequence into one that can produce errors of the specified failure type.
///
/// ## Generic Parameters
///
/// - `Element`: The output element type after transformation.
/// - `Failure`: The error type that the transform function can throw.
/// - `Value`: The input element type from the upstream sequence.
/// - `Upstream`: The upstream async sequence type that never throws.
@available(Configuration 1.0, *)
private struct MapThrowingAsyncSequence<Element, Failure: Error, Value, Upstream: AsyncSequence<Value, Never>> {

    /// The upstream async sequence to transform.
    var upstream: Upstream

    /// The throwing transform function to apply to each element.
    var transform: (Value) throws(Failure) -> Element
}

@available(Configuration 1.0, *)
extension MapThrowingAsyncSequence: AsyncSequence {

    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    func makeAsyncIterator() -> Iterator {
        Iterator(upstream: upstream.makeAsyncIterator(), transform: transform)
    }

    /// An async iterator that applies a throwing transform to upstream elements.
    ///
    /// This iterator wraps the upstream iterator and applies the transform function
    /// to each element, handling both successful transformations and thrown errors.
    struct Iterator: AsyncIteratorProtocol {

        /// The upstream iterator providing source elements.
        var upstream: Upstream.AsyncIterator?

        /// The throwing transform function to apply.
        var transform: (Value) throws(Failure) -> Element

        // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
        mutating func next(isolation actor: isolated (any Actor)?) async throws(Failure) -> Element? {
            guard let value = await upstream?.next(isolation: actor) else {
                return nil
            }
            do {
                return try transform(value)
            } catch {
                upstream = nil
                throw error
            }
        }
    }
}
