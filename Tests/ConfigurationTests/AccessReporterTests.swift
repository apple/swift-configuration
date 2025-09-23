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

@testable import Configuration
import Testing
import ConfigurationTestingInternal

struct AccessReporterTests {
    /// A boolean raw value where `false` is the only possible and valid value.
    private enum MockLogLevel: String, Hashable {
        case info
    }

    @Test func get() async throws {
        let accessReporter = TestAccessReporter()
        let provider = InMemoryProvider(
            name: "test",
            values: [
                "enabled": true,
                "http.version": 2,
                "http.secret": .init("s3cret", isSecret: true),
                "http.client.timeout": 15.0,
                "http.client.user-agent": "Config/1.0 (Test)",
                "log.level": "invalid",
            ]
        )
        let config = ConfigReader(provider: provider, accessReporter: accessReporter)

        let lineOffset = #line

        // Hit
        #expect(config.bool(forKey: "enabled") == true)

        // Miss
        #expect(config.bool(forKey: "nopeEnabled") == nil)

        // Miss with default
        #expect(config.bool(forKey: "nopeEnabled", default: true) == true)

        // Miss required
        let errorA = #expect(throws: ConfigError.self) {
            try config.requiredBool(forKey: "nopeEnabled")
        }
        #expect(errorA == .missingRequiredConfigValue(.init(["nopeEnabled"])))

        // Miss based on incorrect type, fall back to nil
        #expect(config.string(forKey: "enabled") == nil)

        // Miss based on incorrect type, fall back to default
        #expect(config.string(forKey: "enabled", default: "nope") == "nope")

        // Miss required + incorrect type, fall back to nil
        let errorB = #expect(throws: ConfigError.self) {
            try config.requiredString(forKey: "enabled")
        }
        #expect(errorB == .configValueNotConvertible(name: "enabled", type: .string))

        // Miss based on fail-able initializer of the RawRepresentable, fallback to nil
        #expect(config.string(forKey: "log.level", as: MockLogLevel.self) == nil)

        // Miss based on fail-able initializer of the RawRepresentable, fallback to default
        #expect(config.string(forKey: "log.level", as: MockLogLevel.self, default: .info) == .info)

        let events = accessReporter.events
        try #require(events.count == 9)

        #expect(events[0].metadata.accessKind == .get)
        #expect(events[0].metadata.key == .init(["enabled"]))
        #expect(events[0].metadata.sourceLocation.fileID == "ConfigurationTests/AccessReporterTests.swift")
        #expect(events[0].metadata.sourceLocation.line == lineOffset + 3)
        try #require(events[0].providerResults.count == 1)
        #expect(events[0].providerResults[0].providerName == "InMemoryProvider[test]")
        #expect(events[0].conversionError == nil)
        try #expect(events[0].providerResults[0].result.get() == .init(encodedKey: "enabled", value: true))
        try #expect(events[0].result.get() == true)

        #expect(events[1].metadata.accessKind == .get)
        #expect(events[1].metadata.key == .init(["nopeEnabled"]))
        #expect(events[1].metadata.sourceLocation.fileID == "ConfigurationTests/AccessReporterTests.swift")
        #expect(events[1].metadata.sourceLocation.line == lineOffset + 6)
        try #require(events[1].providerResults.count == 1)
        #expect(events[1].providerResults[0].providerName == "InMemoryProvider[test]")
        #expect(events[1].conversionError == nil)
        try #expect(events[1].providerResults[0].result.get() == .init(encodedKey: "nopeEnabled", value: nil))
        try #expect(events[1].result.get() == nil)

        #expect(events[2].metadata.accessKind == .get)
        #expect(events[2].metadata.key == .init(["nopeEnabled"]))
        #expect(events[2].metadata.sourceLocation.fileID == "ConfigurationTests/AccessReporterTests.swift")
        #expect(events[2].metadata.sourceLocation.line == lineOffset + 9)
        try #require(events[2].providerResults.count == 1)
        #expect(events[2].providerResults[0].providerName == "InMemoryProvider[test]")
        #expect(events[2].conversionError == nil)
        try #expect(events[2].providerResults[0].result.get() == .init(encodedKey: "nopeEnabled", value: nil))
        try #expect(events[2].result.get() == true)

        #expect(events[3].metadata.accessKind == .get)
        #expect(events[3].metadata.key == .init(["nopeEnabled"]))
        #expect(events[3].metadata.sourceLocation.fileID == "ConfigurationTests/AccessReporterTests.swift")
        #expect(events[3].metadata.sourceLocation.line == lineOffset + 12)
        try #require(events[3].providerResults.count == 1)
        #expect(events[3].providerResults[0].providerName == "InMemoryProvider[test]")
        try #expect(events[3].providerResults[0].result.get() == .init(encodedKey: "nopeEnabled", value: nil))
        #expect(events[3].conversionError == nil)
        guard case .failure(let error3) = events[3].result else {
            Testing.Issue.record("Unexpected non-error result")
            return
        }
        #expect((error3 as? ConfigError) == .missingRequiredConfigValue(.init(["nopeEnabled"])))

        #expect(events[4].metadata.accessKind == .get)
        #expect(events[4].metadata.key == .init(["enabled"]))
        #expect(events[4].metadata.sourceLocation.fileID == "ConfigurationTests/AccessReporterTests.swift")
        #expect(events[4].metadata.sourceLocation.line == lineOffset + 18)
        try #require(events[4].providerResults.count == 1)
        #expect(events[4].providerResults[0].providerName == "InMemoryProvider[test]")
        guard case .failure(let error4) = events[4].providerResults[0].result else {
            Testing.Issue.record("Unexpected non-error result")
            return
        }
        #expect((error4 as? ConfigError) == .configValueNotConvertible(name: "enabled", type: .string))
        #expect(events[4].conversionError == nil)
        try #expect(events[4].result.get() == nil)

        #expect(events[5].metadata.accessKind == .get)
        #expect(events[5].metadata.key == .init(["enabled"]))
        #expect(events[5].metadata.sourceLocation.fileID == "ConfigurationTests/AccessReporterTests.swift")
        #expect(events[5].metadata.sourceLocation.line == lineOffset + 21)
        try #require(events[5].providerResults.count == 1)
        #expect(events[5].providerResults[0].providerName == "InMemoryProvider[test]")
        guard case .failure(let error5) = events[5].providerResults[0].result else {
            Testing.Issue.record("Unexpected non-error result")
            return
        }
        #expect((error5 as? ConfigError) == .configValueNotConvertible(name: "enabled", type: .string))
        #expect(events[5].conversionError == nil)
        try #expect(events[5].result.get() == "nope")

        #expect(events[6].metadata.accessKind == .get)
        #expect(events[6].metadata.key == .init(["enabled"]))
        #expect(events[6].metadata.sourceLocation.fileID == "ConfigurationTests/AccessReporterTests.swift")
        #expect(events[6].metadata.sourceLocation.line == lineOffset + 24)
        try #require(events[6].providerResults.count == 1)
        #expect(events[6].providerResults[0].providerName == "InMemoryProvider[test]")
        guard case .failure(let error6a) = events[6].providerResults[0].result else {
            Testing.Issue.record("Unexpected non-error result")
            return
        }
        #expect((error6a as? ConfigError) == .configValueNotConvertible(name: "enabled", type: .string))
        #expect(events[6].conversionError == nil)
        guard case .failure(let error6b) = events[6].result else {
            Testing.Issue.record("Unexpected non-error result")
            return
        }
        #expect((error6b as? ConfigError) == .configValueNotConvertible(name: "enabled", type: .string))

        #expect(events[7].metadata.accessKind == .get)
        #expect(events[7].metadata.key == .init(["log", "level"]))
        #expect(events[7].metadata.sourceLocation.fileID == "ConfigurationTests/AccessReporterTests.swift")
        #expect(events[7].metadata.sourceLocation.line == lineOffset + 30)
        try #require(events[7].providerResults.count == 1)
        #expect(events[7].providerResults[0].providerName == "InMemoryProvider[test]")
        try #expect(events[7].providerResults[0].result.get() == .init(encodedKey: "log.level", value: "invalid"))
        try #expect(events[7].result.get() == nil)
        guard let unwrapError7 = events[7].conversionError else {
            Testing.Issue.record("Unexpected missing conversion error")
            return
        }
        #expect(
            (unwrapError7 as? ConfigError) == .configValueFailedToCast(name: "log.level", type: "\(MockLogLevel.self)")
        )

        #expect(events[8].metadata.accessKind == .get)
        #expect(events[8].metadata.key == .init(["log", "level"]))
        #expect(events[8].metadata.sourceLocation.fileID == "ConfigurationTests/AccessReporterTests.swift")
        #expect(events[8].metadata.sourceLocation.line == lineOffset + 33)
        try #require(events[8].providerResults.count == 1)
        #expect(events[8].providerResults[0].providerName == "InMemoryProvider[test]")
        try #expect(events[8].providerResults[0].result.get() == .init(encodedKey: "log.level", value: "invalid"))
        try #expect(events[8].result.get() == "info")
        guard let unwrapError8 = events[8].conversionError else {
            Testing.Issue.record("Unexpected missing conversion error")
            return
        }
        #expect(
            (unwrapError8 as? ConfigError) == .configValueFailedToCast(name: "log.level", type: "\(MockLogLevel.self)")
        )
    }

    @Test func fetch() async throws {
        let accessReporter = TestAccessReporter()
        let provider = InMemoryProvider(
            name: "test",
            values: [
                "enabled": true,
                "http.version": 2,
                "http.secret": .init("s3cret", isSecret: true),
                "http.client.timeout": 15.0,
                "http.client.user-agent": "Config/1.0 (Test)",
                "log.level": "invalid",
            ]
        )
        let config = ConfigReader(provider: provider, accessReporter: accessReporter)

        let lineOffset = #line

        // Hit
        #expect(try await config.fetchBool(forKey: "enabled") == true)

        // Miss
        #expect(try await config.fetchBool(forKey: "nopeEnabled") == nil)

        // Miss with default
        #expect(try await config.fetchBool(forKey: "nopeEnabled", default: true) == true)

        // Miss required
        let errorA = await #expect(throws: ConfigError.self) {
            try await config.fetchRequiredBool(forKey: "nopeEnabled")
        }
        #expect(errorA == .missingRequiredConfigValue(.init(["nopeEnabled"])))

        // Miss based on incorrect type, throw the error up
        let errorB = await #expect(throws: ConfigError.self) {
            try await config.fetchString(forKey: "enabled")
        }
        #expect(errorB == .configValueNotConvertible(name: "enabled", type: .string))

        // Miss based on incorrect type, throws the error up
        let errorC = await #expect(throws: ConfigError.self) {
            try await config.fetchString(forKey: "enabled", default: "nope")
        }
        #expect(errorC == .configValueNotConvertible(name: "enabled", type: .string))

        // Miss required + incorrect type, fall back to nil
        let errorD = await #expect(throws: ConfigError.self) {
            try await config.fetchRequiredString(forKey: "enabled")
        }
        #expect(errorD == .configValueNotConvertible(name: "enabled", type: .string))

        // Miss based on fail-able initializer of the RawRepresentable, fallback to nil
        let errorF = await #expect(throws: ConfigError.self) {
            try await config.fetchString(forKey: "log.level", as: MockLogLevel.self)
        }
        #expect(errorF == .configValueFailedToCast(name: "log.level", type: "\(MockLogLevel.self)"))

        // Miss based on fail-able initializer of the RawRepresentable, fallback to default
        let errorG = await #expect(throws: ConfigError.self) {
            try await config.fetchString(forKey: "log.level", as: MockLogLevel.self, default: .info)
        }
        #expect(errorG == .configValueFailedToCast(name: "log.level", type: "\(MockLogLevel.self)"))

        let events = accessReporter.events
        try #require(events.count == 9)

        #expect(events[0].metadata.accessKind == .fetch)
        #expect(events[0].metadata.key == .init(["enabled"]))
        #expect(events[0].metadata.sourceLocation.fileID == "ConfigurationTests/AccessReporterTests.swift")
        #expect(events[0].metadata.sourceLocation.line == lineOffset + 3)
        try #require(events[0].providerResults.count == 1)
        #expect(events[0].providerResults[0].providerName == "InMemoryProvider[test]")
        try #expect(events[0].providerResults[0].result.get() == .init(encodedKey: "enabled", value: true))
        try #expect(events[0].result.get() == true)

        #expect(events[1].metadata.accessKind == .fetch)
        #expect(events[1].metadata.key == .init(["nopeEnabled"]))
        #expect(events[1].metadata.sourceLocation.fileID == "ConfigurationTests/AccessReporterTests.swift")
        #expect(events[1].metadata.sourceLocation.line == lineOffset + 6)
        try #require(events[1].providerResults.count == 1)
        #expect(events[1].providerResults[0].providerName == "InMemoryProvider[test]")
        try #expect(events[1].providerResults[0].result.get() == .init(encodedKey: "nopeEnabled", value: nil))
        try #expect(events[1].result.get() == nil)

        #expect(events[2].metadata.accessKind == .fetch)
        #expect(events[2].metadata.key == .init(["nopeEnabled"]))
        #expect(events[2].metadata.sourceLocation.fileID == "ConfigurationTests/AccessReporterTests.swift")
        #expect(events[2].metadata.sourceLocation.line == lineOffset + 9)
        try #require(events[2].providerResults.count == 1)
        #expect(events[2].providerResults[0].providerName == "InMemoryProvider[test]")
        try #expect(events[2].providerResults[0].result.get() == .init(encodedKey: "nopeEnabled", value: nil))
        try #expect(events[2].result.get() == true)

        #expect(events[3].metadata.accessKind == .fetch)
        #expect(events[3].metadata.key == .init(["nopeEnabled"]))
        #expect(events[3].metadata.sourceLocation.fileID == "ConfigurationTests/AccessReporterTests.swift")
        #expect(events[3].metadata.sourceLocation.line == lineOffset + 12)
        try #require(events[3].providerResults.count == 1)
        #expect(events[3].providerResults[0].providerName == "InMemoryProvider[test]")
        try #expect(events[3].providerResults[0].result.get() == .init(encodedKey: "nopeEnabled", value: nil))
        guard case .failure(let error3) = events[3].result else {
            Testing.Issue.record("Unexpected non-error result")
            return
        }
        #expect((error3 as? ConfigError) == .missingRequiredConfigValue(.init(["nopeEnabled"])))

        #expect(events[4].metadata.accessKind == .fetch)
        #expect(events[4].metadata.key == .init(["enabled"]))
        #expect(events[4].metadata.sourceLocation.fileID == "ConfigurationTests/AccessReporterTests.swift")
        #expect(events[4].metadata.sourceLocation.line == lineOffset + 18)
        try #require(events[4].providerResults.count == 1)
        #expect(events[4].providerResults[0].providerName == "InMemoryProvider[test]")
        guard case .failure(let error4a) = events[4].providerResults[0].result else {
            Testing.Issue.record("Unexpected non-error result")
            return
        }
        #expect((error4a as? ConfigError) == .configValueNotConvertible(name: "enabled", type: .string))
        guard case .failure(let error4b) = events[4].result else {
            Testing.Issue.record("Unexpected non-error result")
            return
        }
        #expect((error4b as? ConfigError) == .configValueNotConvertible(name: "enabled", type: .string))

        #expect(events[5].metadata.accessKind == .fetch)
        #expect(events[5].metadata.key == .init(["enabled"]))
        #expect(events[5].metadata.sourceLocation.fileID == "ConfigurationTests/AccessReporterTests.swift")
        #expect(events[5].metadata.sourceLocation.line == lineOffset + 24)
        try #require(events[5].providerResults.count == 1)
        #expect(events[5].providerResults[0].providerName == "InMemoryProvider[test]")
        guard case .failure(let error5a) = events[5].providerResults[0].result else {
            Testing.Issue.record("Unexpected non-error result")
            return
        }
        #expect((error5a as? ConfigError) == .configValueNotConvertible(name: "enabled", type: .string))
        guard case .failure(let error5b) = events[5].result else {
            Testing.Issue.record("Unexpected non-error result")
            return
        }
        #expect((error5b as? ConfigError) == .configValueNotConvertible(name: "enabled", type: .string))

        #expect(events[6].metadata.accessKind == .fetch)
        #expect(events[6].metadata.key == .init(["enabled"]))
        #expect(events[6].metadata.sourceLocation.fileID == "ConfigurationTests/AccessReporterTests.swift")
        #expect(events[6].metadata.sourceLocation.line == lineOffset + 30)
        try #require(events[6].providerResults.count == 1)
        #expect(events[6].providerResults[0].providerName == "InMemoryProvider[test]")
        guard case .failure(let error6a) = events[6].providerResults[0].result else {
            Testing.Issue.record("Unexpected non-error result")
            return
        }
        #expect((error6a as? ConfigError) == .configValueNotConvertible(name: "enabled", type: .string))
        guard case .failure(let error6b) = events[6].result else {
            Testing.Issue.record("Unexpected non-error result")
            return
        }
        #expect((error6b as? ConfigError) == .configValueNotConvertible(name: "enabled", type: .string))

        #expect(events[7].metadata.accessKind == .fetch)
        #expect(events[7].metadata.key == .init(["log", "level"]))
        #expect(events[7].metadata.sourceLocation.fileID == "ConfigurationTests/AccessReporterTests.swift")
        #expect(events[7].metadata.sourceLocation.line == lineOffset + 36)
        try #require(events[7].providerResults.count == 1)
        #expect(events[7].providerResults[0].providerName == "InMemoryProvider[test]")
        try #expect(events[7].providerResults[0].result.get() == .init(encodedKey: "log.level", value: "invalid"))
        let resultError7 = #expect(throws: ConfigError.self) {
            try events[7].result.get()
        }
        #expect(resultError7 == .configValueFailedToCast(name: "log.level", type: "\(MockLogLevel.self)"))
        guard let unwrapError7 = events[7].conversionError else {
            Testing.Issue.record("Unexpected missing conversion error")
            return
        }
        #expect(
            (unwrapError7 as? ConfigError) == .configValueFailedToCast(name: "log.level", type: "\(MockLogLevel.self)")
        )

        #expect(events[8].metadata.accessKind == .fetch)
        #expect(events[8].metadata.key == .init(["log", "level"]))
        #expect(events[8].metadata.sourceLocation.fileID == "ConfigurationTests/AccessReporterTests.swift")
        #expect(events[8].metadata.sourceLocation.line == lineOffset + 42)
        try #require(events[8].providerResults.count == 1)
        #expect(events[8].providerResults[0].providerName == "InMemoryProvider[test]")
        try #expect(events[8].providerResults[0].result.get() == .init(encodedKey: "log.level", value: "invalid"))
        let resultError8 = #expect(throws: ConfigError.self) {
            try events[8].result.get()
        }
        #expect(resultError8 == .configValueFailedToCast(name: "log.level", type: "\(MockLogLevel.self)"))
        guard let unwrapError8 = events[8].conversionError else {
            Testing.Issue.record("Unexpected missing conversion error")
            return
        }
        #expect(
            (unwrapError8 as? ConfigError) == .configValueFailedToCast(name: "log.level", type: "\(MockLogLevel.self)")
        )
    }

    @Test func watch() async throws {
        let accessReporter = TestAccessReporter()
        let provider = InMemoryProvider(
            name: "test",
            values: [
                "enabled": true,
                "http.version": 2,
                "http.secret": .init("s3cret", isSecret: true),
                "http.client.timeout": 15.0,
                "http.client.user-agent": "Config/1.0 (Test)",
                "log.level": "invalid",
            ]
        )
        let config = ConfigReader(provider: provider, accessReporter: accessReporter)

        let lineOffset = #line

        // Hit
        #expect(try await config.watchBool(forKey: "enabled") { await $0.first } == true)

        // Miss
        #expect(try await config.watchBool(forKey: "nopeEnabled") { await $0.first } == .some(nil))

        // Miss with default
        #expect(try await config.watchBool(forKey: "nopeEnabled", default: true) { await $0.first } == true)

        // Miss required
        let errorA = await #expect(throws: ConfigError.self) {
            try await config.watchRequiredBool(forKey: "nopeEnabled") { try await $0.first }
        }
        #expect(errorA == .missingRequiredConfigValue(.init(["nopeEnabled"])))

        // Miss based on incorrect type, fall back to nil
        #expect(try await config.watchString(forKey: "enabled") { await $0.first } == .some(nil))

        // Miss based on incorrect type, fall back to default
        #expect(try await config.watchString(forKey: "enabled", default: "nope") { await $0.first } == "nope")

        // Miss required + incorrect type, fall back to nil
        let errorB = await #expect(throws: ConfigError.self) {
            try await config.watchRequiredString(forKey: "enabled") { try await $0.first }
        }
        #expect(errorB == .configValueNotConvertible(name: "enabled", type: .string))

        // Miss based on fail-able initializer of the RawRepresentable, fallback to nil
        #expect(
            try await config.watchString(forKey: "log.level", as: MockLogLevel.self) { await $0.first } == .some(nil)
        )

        // Miss based on fail-able initializer of the RawRepresentable, fallback to default
        #expect(
            try await config.watchString(forKey: "log.level", as: MockLogLevel.self, default: .info) { await $0.first }
                == .info
        )

        let events = accessReporter.events
        try #require(events.count == 9)

        #expect(events[0].metadata.accessKind == .watch)
        #expect(events[0].metadata.key == .init(["enabled"]))
        #expect(events[0].metadata.sourceLocation.fileID == "ConfigurationTests/AccessReporterTests.swift")
        #expect(events[0].metadata.sourceLocation.line == lineOffset + 3)
        try #require(events[0].providerResults.count == 1)
        #expect(events[0].providerResults[0].providerName == "InMemoryProvider[test]")
        #expect(events[3].conversionError == nil)
        try #expect(events[0].providerResults[0].result.get() == .init(encodedKey: "enabled", value: true))
        try #expect(events[0].result.get() == true)

        #expect(events[1].metadata.accessKind == .watch)
        #expect(events[1].metadata.key == .init(["nopeEnabled"]))
        #expect(events[1].metadata.sourceLocation.fileID == "ConfigurationTests/AccessReporterTests.swift")
        #expect(events[1].metadata.sourceLocation.line == lineOffset + 6)
        try #require(events[1].providerResults.count == 1)
        #expect(events[1].providerResults[0].providerName == "InMemoryProvider[test]")
        #expect(events[3].conversionError == nil)
        try #expect(events[1].providerResults[0].result.get() == .init(encodedKey: "nopeEnabled", value: nil))
        try #expect(events[1].result.get() == nil)

        #expect(events[2].metadata.accessKind == .watch)
        #expect(events[2].metadata.key == .init(["nopeEnabled"]))
        #expect(events[2].metadata.sourceLocation.fileID == "ConfigurationTests/AccessReporterTests.swift")
        #expect(events[2].metadata.sourceLocation.line == lineOffset + 9)
        try #require(events[2].providerResults.count == 1)
        #expect(events[2].providerResults[0].providerName == "InMemoryProvider[test]")
        #expect(events[3].conversionError == nil)
        try #expect(events[2].providerResults[0].result.get() == .init(encodedKey: "nopeEnabled", value: nil))
        try #expect(events[2].result.get() == true)

        #expect(events[3].metadata.accessKind == .watch)
        #expect(events[3].metadata.key == .init(["nopeEnabled"]))
        #expect(events[3].metadata.sourceLocation.fileID == "ConfigurationTests/AccessReporterTests.swift")
        #expect(events[3].metadata.sourceLocation.line == lineOffset + 12)
        try #require(events[3].providerResults.count == 1)
        #expect(events[3].providerResults[0].providerName == "InMemoryProvider[test]")
        try #expect(events[3].providerResults[0].result.get() == .init(encodedKey: "nopeEnabled", value: nil))
        #expect(events[3].conversionError == nil)
        guard case .failure(let error3) = events[3].result else {
            Testing.Issue.record("Unexpected non-error result")
            return
        }
        #expect((error3 as? ConfigError) == .missingRequiredConfigValue(.init(["nopeEnabled"])))

        #expect(events[4].metadata.accessKind == .watch)
        #expect(events[4].metadata.key == .init(["enabled"]))
        #expect(events[4].metadata.sourceLocation.fileID == "ConfigurationTests/AccessReporterTests.swift")
        #expect(events[4].metadata.sourceLocation.line == lineOffset + 18)
        try #require(events[4].providerResults.count == 1)
        #expect(events[4].providerResults[0].providerName == "InMemoryProvider[test]")
        guard case .failure(let error4) = events[4].providerResults[0].result else {
            Testing.Issue.record("Unexpected non-error result")
            return
        }
        #expect((error4 as? ConfigError) == .configValueNotConvertible(name: "enabled", type: .string))
        #expect(events[3].conversionError == nil)
        try #expect(events[4].result.get() == nil)

        #expect(events[5].metadata.accessKind == .watch)
        #expect(events[5].metadata.key == .init(["enabled"]))
        #expect(events[5].metadata.sourceLocation.fileID == "ConfigurationTests/AccessReporterTests.swift")
        #expect(events[5].metadata.sourceLocation.line == lineOffset + 21)
        try #require(events[5].providerResults.count == 1)
        #expect(events[5].providerResults[0].providerName == "InMemoryProvider[test]")
        guard case .failure(let error5) = events[5].providerResults[0].result else {
            Testing.Issue.record("Unexpected non-error result")
            return
        }
        #expect((error5 as? ConfigError) == .configValueNotConvertible(name: "enabled", type: .string))
        #expect(events[3].conversionError == nil)
        try #expect(events[5].result.get() == "nope")

        #expect(events[6].metadata.accessKind == .watch)
        #expect(events[6].metadata.key == .init(["enabled"]))
        #expect(events[6].metadata.sourceLocation.fileID == "ConfigurationTests/AccessReporterTests.swift")
        #expect(events[6].metadata.sourceLocation.line == lineOffset + 24)
        try #require(events[6].providerResults.count == 1)
        #expect(events[6].providerResults[0].providerName == "InMemoryProvider[test]")
        guard case .failure(let error6a) = events[6].providerResults[0].result else {
            Testing.Issue.record("Unexpected non-error result")
            return
        }
        #expect((error6a as? ConfigError) == .configValueNotConvertible(name: "enabled", type: .string))
        #expect(events[3].conversionError == nil)
        guard case .failure(let error6b) = events[6].result else {
            Testing.Issue.record("Unexpected non-error result")
            return
        }
        #expect((error6b as? ConfigError) == .configValueNotConvertible(name: "enabled", type: .string))

        #expect(events[7].metadata.accessKind == .watch)
        #expect(events[7].metadata.key == .init(["log", "level"]))
        #expect(events[7].metadata.sourceLocation.fileID == "ConfigurationTests/AccessReporterTests.swift")
        #expect(events[7].metadata.sourceLocation.line == lineOffset + 30)
        try #require(events[7].providerResults.count == 1)
        #expect(events[7].providerResults[0].providerName == "InMemoryProvider[test]")
        try #expect(events[7].providerResults[0].result.get() == .init(encodedKey: "log.level", value: "invalid"))
        try #expect(events[7].result.get() == nil)
        guard let unwrapError7 = events[7].conversionError else {
            Testing.Issue.record("Unexpected missing conversion error")
            return
        }
        #expect(
            (unwrapError7 as? ConfigError) == .configValueFailedToCast(name: "log.level", type: "\(MockLogLevel.self)")
        )

        #expect(events[8].metadata.accessKind == .watch)
        #expect(events[8].metadata.key == .init(["log", "level"]))
        #expect(events[8].metadata.sourceLocation.fileID == "ConfigurationTests/AccessReporterTests.swift")
        #expect(events[8].metadata.sourceLocation.line == lineOffset + 35)
        try #require(events[8].providerResults.count == 1)
        #expect(events[8].providerResults[0].providerName == "InMemoryProvider[test]")
        try #expect(events[8].providerResults[0].result.get() == .init(encodedKey: "log.level", value: "invalid"))
        try #expect(events[8].result.get() == "info")
        guard let unwrapError8 = events[8].conversionError else {
            Testing.Issue.record("Unexpected missing conversion error")
            return
        }
        #expect(
            (unwrapError8 as? ConfigError) == .configValueFailedToCast(name: "log.level", type: "\(MockLogLevel.self)")
        )
    }
}
