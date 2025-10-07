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

package import Configuration
import Synchronization
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import Testing

/// A test-only access reporter that records events for later inspection.
@available(Configuration 1.0, *)
package final class TestAccessReporter: Sendable {

    /// The internal storage.
    private struct Storage {

        /// The underlying events reported so far.
        var events: [AccessEvent] = []
    }

    /// The internal storage.
    private let storage: Mutex<Storage>

    /// Creates a new reporter.
    package init() {
        self.storage = .init(.init())
    }

    /// All recorded access events, in the order they were reported.
    package var events: [AccessEvent] {
        storage.withLock { $0.events }
    }
}

@available(Configuration 1.0, *)
extension TestAccessReporter: AccessReporter {
    package func report(_ event: AccessEvent) {
        storage.withLock { $0.events.append(event) }
    }
}
