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

#if Logging

import Testing
import Logging
@testable import ConfigurationTestingInternal

struct CollectingLogHandleTests {
    @available(Configuration 1.0, *)
    @Test func logsEqualAndAboveLogHandlerLevel() throws {
        let levels = Logger.Level.allCases.sorted()
        for threshold in levels {
            var collectingLogHandler = CollectingLogHandler()
            collectingLogHandler.logLevel = threshold
            let logger = Logger(label: "Test", factory: { _ in collectingLogHandler })

            for level in levels {
                logger.log(
                    level: level,
                    "\(level.description)",
                    metadata: ["threshold": "\(threshold.description)"]
                )
            }

            let entries = collectingLogHandler.currentEntries
            #expect(
                entries
                    == levels.filter { $0 >= threshold }
                    .map {
                        Entry(
                            level: $0,
                            message: $0.description,
                            metadata: ["threshold": "\(threshold.description)"]
                        )
                    }
            )
        }
    }
}

#endif
