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

import ConfigurationTestingInternal
import Testing
@testable import Configuration

struct IntegerRawRepresentableTests {
    private enum UnsignedCode: UInt8, Equatable {
        case ready = 1
    }

    private enum SignedCode: Int8, Equatable {
        case negative = -1
    }

    private enum IntCode: Int, Equatable {
        case ready = 1
    }

    private enum WideCode: UInt64, Equatable {
        case maximum = 18_446_744_073_709_551_615
    }

    @available(Configuration 1.0, *)
    @Test func exactIntegerConversion() throws {
        let config = ConfigReader(
            provider: InMemoryProvider(
                values: [
                    "unsigned.ready": ConfigValue(1, isSecret: false),
                    "unsigned.negative": ConfigValue(-1, isSecret: false),
                    "unsigned.overflow": ConfigValue(256, isSecret: false),
                    "unsigned.unknown": ConfigValue(2, isSecret: false),
                    "unsigned.array": ConfigValue([1], isSecret: false),
                    "unsigned.arrayOverflow": ConfigValue([1, 256], isSecret: false),
                    "signed.negative": ConfigValue(-1, isSecret: false),
                    "int.ready": ConfigValue(1, isSecret: false),
                ]
            )
        )

        #expect(config.int(forKey: "unsigned.ready", as: UnsignedCode.self) == .ready)
        #expect(config.int(forKey: "unsigned.negative", as: UnsignedCode.self) == nil)
        #expect(config.int(forKey: "unsigned.overflow", as: UnsignedCode.self) == nil)
        #expect(config.int(forKey: "unsigned.unknown", as: UnsignedCode.self) == nil)
        #expect(config.intArray(forKey: "unsigned.array", as: UnsignedCode.self) == [.ready])
        #expect(config.intArray(forKey: "unsigned.arrayOverflow", as: UnsignedCode.self) == nil)
        #expect(config.int(forKey: "signed.negative", as: SignedCode.self) == .negative)
        #expect(config.int(forKey: "int.ready", as: IntCode.self) == .ready)

        let error = #expect(throws: ConfigError.self) {
            try config.requiredInt(forKey: "unsigned.negative", as: UnsignedCode.self)
        }
        #expect(
            error
                == .configValueFailedToCast(
                    name: "unsigned.negative",
                    type: "\(UnsignedCode.self)"
                )
        )

        let snapshot = config.snapshot()
        #expect(snapshot.int(forKey: "unsigned.ready", as: UnsignedCode.self) == .ready)
        #expect(snapshot.int(forKey: "unsigned.overflow", as: UnsignedCode.self) == nil)
        #expect(snapshot.intArray(forKey: "unsigned.array", as: UnsignedCode.self) == [.ready])
        #expect(snapshot.intArray(forKey: "unsigned.arrayOverflow", as: UnsignedCode.self) == nil)
        #expect(snapshot.int(forKey: "signed.negative", as: SignedCode.self) == .negative)
        #expect(snapshot.int(forKey: "int.ready", as: IntCode.self) == .ready)
    }

    @available(Configuration 1.0, *)
    @Test func unrepresentableDefaultsDoNotTrap() throws {
        let accessReporter = TestAccessReporter()
        let config = ConfigReader(
            provider: InMemoryProvider(values: [:]),
            accessReporter: accessReporter
        )

        #expect(config.int(forKey: "wide", as: WideCode.self, default: .maximum) == .maximum)
        #expect(config.intArray(forKey: "wideArray", as: WideCode.self, default: [.maximum]) == [.maximum])

        let events = accessReporter.events
        try #require(events.count == 2)

        for (event, key) in zip(events, ["wide", "wideArray"]) {
            let error = #expect(throws: ConfigError.self) {
                try event.result.get()
            }
            #expect(error == .configValueFailedToCast(name: key, type: "Int"))
        }
    }
}
