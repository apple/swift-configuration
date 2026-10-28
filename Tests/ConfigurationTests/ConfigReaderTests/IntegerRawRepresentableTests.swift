//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftConfiguration open source project
//
// Copyright (c) 2026 Apple Inc. and the SwiftConfiguration project authors
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
    enum UnsignedCode: UInt8, Equatable {
        case ready = 1
    }

    enum SignedCode: Int8, Equatable {
        case negative = -1
    }

    enum IntCode: Int, Equatable {
        case ready = 1
    }

    /// A type with raw values on both sides of `Int.max`, on every platform.
    struct WideCode: RawRepresentable, Equatable {
        var rawValue: UInt64

        static let intMax = WideCode(rawValue: UInt64(Int.max))
        static let tooLarge = WideCode(rawValue: UInt64(Int.max) + 1)
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
    @Test func defaultsWithinIntRangeAreReported() async throws {
        let accessReporter = TestAccessReporter()
        let config = ConfigReader(
            provider: InMemoryProvider(values: [:]),
            accessReporter: accessReporter
        )

        #expect(config.int(forKey: "wide", as: WideCode.self, default: .intMax) == .intMax)
        #expect(config.intArray(forKey: "wideArray", as: WideCode.self, default: [.intMax]) == [.intMax])
        #expect(try await config.fetchInt(forKey: "wide", as: WideCode.self, default: .intMax) == .intMax)
        #expect(config.snapshot().int(forKey: "wide", as: WideCode.self, default: .intMax) == .intMax)
        #expect(
            try await config.watchInt(forKey: "wide", as: WideCode.self, default: .intMax, updatesHandler: awaitFirst)
                == .intMax
        )

        let events = accessReporter.events
        try #require(events.count == 5)
        let expectedContents: [ConfigContent] = [
            .int(Int.max), .intArray([Int.max]), .int(Int.max), .int(Int.max), .int(Int.max),
        ]
        for (event, expectedContent) in zip(events, expectedContents) {
            #expect(event.conversionError == nil)
            #expect(try event.result.get()?.content == expectedContent)
        }
    }

    #if os(macOS) || os(Linux) || os(Windows)
    @available(Configuration 1.0, *)
    @Test func defaultsOutsideIntRangeTrap() async {
        let result = await #expect(processExitsWith: .failure, observing: [\.standardErrorContent]) {
            let config = ConfigReader(provider: InMemoryProvider(values: [:]))
            _ = config.int(forKey: "wide", as: WideCode.self, default: .tooLarge)
        }
        let message = String(decoding: result?.standardErrorContent ?? [], as: UTF8.self)
        #expect(
            message.contains(
                "The default value for config key 'wide' at ConfigurationTests/IntegerRawRepresentableTests.swift:"
            )
        )
        await #expect(processExitsWith: .failure) {
            let config = ConfigReader(provider: InMemoryProvider(values: [:]))
            _ = config.intArray(forKey: "wide", as: WideCode.self, default: [.intMax, .tooLarge])
        }
        await #expect(processExitsWith: .failure) {
            let config = ConfigReader(provider: InMemoryProvider(values: [:]))
            _ = try await config.fetchInt(forKey: "wide", as: WideCode.self, default: .tooLarge)
        }
        await #expect(processExitsWith: .failure) {
            let config = ConfigReader(provider: InMemoryProvider(values: [:]))
            _ = try await config.fetchIntArray(forKey: "wide", as: WideCode.self, default: [.tooLarge])
        }
        await #expect(processExitsWith: .failure) {
            let config = ConfigReader(provider: InMemoryProvider(values: [:]))
            try await config.watchInt(forKey: "wide", as: WideCode.self, default: .tooLarge) { _ in }
        }
        await #expect(processExitsWith: .failure) {
            let config = ConfigReader(provider: InMemoryProvider(values: [:]))
            try await config.watchIntArray(forKey: "wide", as: WideCode.self, default: [.tooLarge]) { _ in }
        }
        await #expect(processExitsWith: .failure) {
            let snapshot = ConfigReader(provider: InMemoryProvider(values: [:])).snapshot()
            _ = snapshot.int(forKey: "wide", as: WideCode.self, default: .tooLarge)
        }
        await #expect(processExitsWith: .failure) {
            let snapshot = ConfigReader(provider: InMemoryProvider(values: [:])).snapshot()
            _ = snapshot.intArray(forKey: "wide", as: WideCode.self, default: [.tooLarge])
        }
    }
    #endif

    /// A type whose `configInt` differs from its raw value, to tell which overload was used.
    enum DualCode: UInt8, ExpressibleByConfigInt, Equatable {
        case one = 1
        case two = 2

        init?(configInt: Int) {
            guard let rawValue = UInt8(exactly: configInt / 10) else {
                return nil
            }
            self.init(rawValue: rawValue)
        }

        var configInt: Int { Int(rawValue) * 10 }

        var description: String { "\(rawValue)" }
    }

    /// A type whose `configInt` differs from its raw value, to tell which overload was used.
    enum IntDualCode: Int, ExpressibleByConfigInt, Equatable {
        case one = 1
        case two = 2

        init?(configInt: Int) {
            self.init(rawValue: configInt / 10)
        }

        var configInt: Int { rawValue * 10 }

        var description: String { "\(rawValue)" }
    }

    @available(Configuration 1.0, *)
    @Test func expressibleByConfigIntIsPreferred() async throws {
        let accessReporter = TestAccessReporter()
        let config = ConfigReader(
            provider: InMemoryProvider(
                values: [
                    "scalar": ConfigValue(20, isSecret: false),
                    "array": ConfigValue([10, 20], isSecret: false),
                ]
            ),
            accessReporter: accessReporter
        )

        #expect(config.int(forKey: "scalar", as: DualCode.self) == .two)
        #expect(try config.requiredInt(forKey: "scalar", as: DualCode.self) == .two)
        #expect(config.intArray(forKey: "array", as: DualCode.self) == [.one, .two])
        #expect(try await config.fetchInt(forKey: "scalar", as: DualCode.self) == .two)
        #expect(config.int(forKey: "scalar", as: IntDualCode.self) == .two)
        #expect(config.intArray(forKey: "array", as: IntDualCode.self) == [.one, .two])

        // The default is returned either way, but only the preferred overload reports it as its config integer.
        #expect(config.int(forKey: "missing", as: DualCode.self, default: .one) == .one)
        #expect(try accessReporter.events.last?.result.get()?.content == .int(10))
        #expect(
            try await config.watchInt(forKey: "missing", as: DualCode.self, default: .one, updatesHandler: awaitFirst)
                == .one
        )
        #expect(try accessReporter.events.last?.result.get()?.content == .int(10))

        let snapshot = config.snapshot()
        #expect(snapshot.int(forKey: "scalar", as: DualCode.self) == .two)
        #expect(snapshot.int(forKey: "scalar", as: IntDualCode.self) == .two)
    }
}
