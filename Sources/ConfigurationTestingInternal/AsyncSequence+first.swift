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

extension AsyncSequence where Failure == Never {
    /// Returns the first element of the async sequence, or nil if the sequence completes before emitting an element.
    package var first: Element? {
        get async {
            await self.first(where: { _ in true })
        }
    }
}

extension AsyncSequence {
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
package func awaitFirst<Value: Sendable>(updates: any AsyncSequence<Value, Never>) async -> Value? {
    await updates.first
}

/// Returns the first element of the async sequence, or nil if the sequence completes before emitting an element.
/// - Parameter updates: The async sequence to get the first element from.
/// - Returns: The first element, or nil if empty.
/// - Throws: Any error thrown by the async sequence.
package func awaitFirst<Value: Sendable>(updates: any AsyncSequence<Value, any Error>) async throws -> Value? {
    try await updates.first
}
