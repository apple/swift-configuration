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
@testable import Configuration
import Foundation
import SystemPackage
import ConfigurationTestingInternal

struct FileAccessLoggerTests {
    @available(Configuration 1.0, *)
    @Test func test() throws {

        let readString: String
        do {
            let pipe = Pipe()
            let readHandle = pipe.fileHandleForReading
            let writeHandle = pipe.fileHandleForWriting
            let writeDescriptor = FileDescriptor(rawValue: writeHandle.fileDescriptor)
            let logger = try FileAccessLogger(fileDescriptor: writeDescriptor, timeZone: .gmt)
            let now = Date(timeIntervalSince1970: 1_746_603_594)

            logger.report(
                .init(
                    metadata: .init(
                        accessKind: .get,
                        key: ["foo", "bar"],
                        valueType: .int,
                        sourceLocation: .init(fileID: "MagicModule/MagicFile.swift", line: 24),
                        accessTimestamp: now
                    ),
                    providerResults: [
                        .init(
                            providerName: "MagicProvider",
                            result: .success(
                                .init(
                                    encodedKey: "foo.bar",
                                    value: 1234
                                )
                            )
                        )
                    ],
                    result: .success(1234)
                )
            )
            logger.report(
                .init(
                    metadata: .init(
                        accessKind: .fetch,
                        key: ["foo", "none"],
                        valueType: .double,
                        sourceLocation: .init(fileID: "MagicModule/MagicFile2.swift", line: 34),
                        accessTimestamp: now.addingTimeInterval(1)
                    ),
                    providerResults: [
                        .init(
                            providerName: "MagicProvider",
                            result: .success(
                                .init(
                                    encodedKey: "foo.none",
                                    value: nil
                                )
                            )
                        )
                    ],
                    result: .success(nil)
                )
            )
            logger.report(
                .init(
                    metadata: .init(
                        accessKind: .fetch,
                        key: ["foo", "default"],
                        valueType: .string,
                        sourceLocation: .init(fileID: "MagicModule/MagicFile3.swift", line: 45),
                        accessTimestamp: now.addingTimeInterval(2)
                    ),
                    providerResults: [
                        .init(
                            providerName: "MagicProvider",
                            result: .success(
                                .init(
                                    encodedKey: "foo.default",
                                    value: nil
                                )
                            )
                        )
                    ],
                    result: .success("default_value")
                )
            )
            logger.report(
                .init(
                    metadata: .init(
                        accessKind: .watch,
                        key: ["foo", "error"],
                        valueType: .string,
                        sourceLocation: .init(fileID: "MagicModule/MagicFile4.swift", line: 56),
                        accessTimestamp: now.addingTimeInterval(3)
                    ),
                    providerResults: [
                        .init(
                            providerName: "MagicProvider",
                            result: .failure(TestProvider.TestError())
                        )
                    ],
                    result: .failure(TestProvider.TestError())
                )
            )
            logger.report(
                .init(
                    metadata: .init(
                        accessKind: .get,
                        key: ["foo", "bass"],
                        valueType: .int,
                        sourceLocation: .init(fileID: "MagicModule/MagicFile.swift", line: 24),
                        accessTimestamp: now
                    ),
                    providerResults: [
                        .init(
                            providerName: "MagicProvider",
                            result: .success(
                                .init(
                                    encodedKey: "foo.bass",
                                    value: 1234
                                )
                            )
                        )
                    ],
                    conversionError: ConfigError.configValueFailedToCast(name: "foo.bass", type: "Logger.Level"),
                    result: .success(1234)
                )
            )
            logger.report(
                .init(
                    metadata: .init(
                        accessKind: .get,
                        key: ["foo", "bat"],
                        valueType: .int,
                        sourceLocation: .init(fileID: "MagicModule/MagicFile.swift", line: 24),
                        accessTimestamp: now
                    ),
                    providerResults: [
                        .init(
                            providerName: "MagicProvider",
                            result: .success(
                                .init(
                                    encodedKey: "foo.bat",
                                    value: 1234
                                )
                            )
                        )
                    ],
                    conversionError: ConfigError.configValueFailedToCast(name: "foo.bat", type: "Logger.Level"),
                    result: .success(.none)  // simple get or default value
                )
            )
            logger.report(
                .init(
                    metadata: .init(
                        accessKind: .watch,
                        key: ["foo", "bah"],
                        valueType: .string,
                        sourceLocation: .init(fileID: "MagicModule/MagicFile4.swift", line: 56),
                        accessTimestamp: now.addingTimeInterval(3)
                    ),
                    providerResults: [
                        .init(
                            providerName: "MagicProvider",
                            result: .failure(TestProvider.TestError())
                        )
                    ],
                    result: .success(nil)  // simple get or default value
                )
            )
            try writeHandle.close()
            readString = try readHandle.readToEnd().flatMap { String(decoding: $0, as: UTF8.self) } ?? ""
        }

        #expect(
            readString == """
                ---
                Emitting config events from process \(ProcessInfo.processInfo.processIdentifier)
                ---
                ✅ foo.bar -> "1234" - provided by MagicProvider / Get int from MagicModule/MagicFile.swift:24 at 2025-05-07T07:39:54.000Z
                🟡 foo.none -> "<nil>" - all providers returned nil / Fetch double from MagicModule/MagicFile2.swift:34 at 2025-05-07T07:39:55.000Z
                🟡 foo.default -> "default_value" - all providers returned nil, got the default value / Fetch string from MagicModule/MagicFile3.swift:45 at 2025-05-07T07:39:56.000Z
                ❌ foo.error -> "<error>" - threw an error: TestError() / Watch string from MagicModule/MagicFile4.swift:56 at 2025-05-07T07:39:57.000Z
                🟡 foo.bass -> "1234" - provided by MagicProvider but failed to convert: Config value for key 'foo.bass' failed to cast to type Logger.Level. / Get int from MagicModule/MagicFile.swift:24 at 2025-05-07T07:39:54.000Z
                🟡 foo.bat -> "<nil>" - provided by MagicProvider but failed to convert: Config value for key 'foo.bat' failed to cast to type Logger.Level. / Get int from MagicModule/MagicFile.swift:24 at 2025-05-07T07:39:54.000Z
                🟡 foo.bah -> "<nil>" - all providers returned nil / Watch string from MagicModule/MagicFile4.swift:56 at 2025-05-07T07:39:57.000Z

                """
        )
    }
}
