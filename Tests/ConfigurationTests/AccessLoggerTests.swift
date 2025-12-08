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
import Configuration
import Logging
import Synchronization
import ConfigurationTestingInternal

struct AccessLoggerTests {
    @available(Configuration 1.0, *)
    @Test func test() throws {
        let collectingLogHandler = CollectingLogHandler()
        let logger = Logger(label: "Test", factory: { _ in collectingLogHandler })
        let accessReporter = AccessLogger(logger: logger)
        let provider = TestProvider(values: [
            ["foo"]: .success("fooValue"),
            ["bar"]: .failure(TestProvider.TestError()),
        ])
        let config = ConfigReader(provider: provider, accessReporter: accessReporter)

        let line = #line
        #expect(try config.requiredString(forKey: "foo") == "fooValue")
        #expect(throws: TestProvider.TestError.self) { try config.requiredInt(forKey: "bar") }

        let entries = collectingLogHandler.currentEntries
        #expect(
            entries == [
                Entry(
                    level: .debug,
                    message: "Config value accessed",
                    metadata: [
                        "counter": "1",
                        "key": "foo",
                        "kind": "get",
                        "location": "ConfigurationTests/AccessLoggerTests.swift:\(line+1)",
                        "value": "[string: fooValue]",
                        "1.providerName": "TestProvider",
                        "1.encodedKey": "foo",
                        "1.value": "[string: fooValue]",
                    ]
                ),
                Entry(
                    level: .debug,
                    message: "Config value accessed",
                    metadata: [
                        "counter": "2",
                        "key": "bar",
                        "kind": "get",
                        "location": "ConfigurationTests/AccessLoggerTests.swift:\(line+2)",
                        "error": "TestError()",
                        "1.providerName": "TestProvider",
                        "1.error": "TestError()",
                    ]
                ),
            ]
        )
    }
}

#endif
