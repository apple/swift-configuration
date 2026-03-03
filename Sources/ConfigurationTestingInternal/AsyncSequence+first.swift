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

@available(Configuration 1.0, *)
extension AsyncSequence where Failure == Never, Self: Sendable {
    /// Returns the first element of the async sequence, or nil if the sequence completes before emitting an element.
    package var first: Element? {
        get async {
            await self.first(where: { _ in true })
        }
    }
}

@available(Configuration 1.0, *)
extension AsyncSequence where Self: Sendable {
    /// Returns the first element of the async sequence, or nil if the sequence completes before emitting an element.
    package var first: Element? {
        get async throws {
            try await self.first(where: { _ in true })
        }
    }
}

/// Returns the first element of the async sequence, or nil if the sequence completes before emitting an element.
/// - Parameter updates: The async sequence to get the first element from.
/// - Returns: The first element, or nil if empty.
@available(Configuration 1.0, *)
package func awaitFirst<Value: Sendable>(updates: any AsyncSequence<Value, Never> & Sendable) async -> Value? {
    await updates.first
}

/// Returns the first element of the async sequence, or nil if the sequence completes before emitting an element.
/// - Parameter updates: The async sequence to get the first element from.
/// - Returns: The first element, or nil if empty.
/// - Throws: Any error thrown by the async sequence.
@available(Configuration 1.0, *)
package func awaitFirst<Value: Sendable>(updates: any AsyncSequence<Value, any Error> & Sendable) async throws -> Value?
{
    try await updates.first
}
