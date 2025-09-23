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
import ConfigurationTestingInternal

struct SecretMarkingTests {

    @Test func secretHandling() throws {
        let provider = InMemoryProvider(values: [
            "public.key": ConfigValue("public-value", isSecret: false),
            "secret.key": ConfigValue("secret-value", isSecret: true),
        ])

        // Add a collector to verify that secret values are properly marked
        let collector = TestAccessReporter()
        let config = ConfigReader(provider: provider, accessReporter: collector)

        _ = config.string(forKey: "public.key")
        _ = config.string(forKey: "secret.key")

        let events = collector.events
        #expect(events.count == 2)
        #expect(try events[0].result.get()?.isSecret == false)
        #expect(try events[1].result.get()?.isSecret == true)
    }

    @Test func get() throws {
        let accessReporter = TestAccessReporter()
        let provider = InMemoryProvider(
            name: "test",
            values: [
                "http.secret": .init("s3cret", isSecret: true),
                "http.client.user-agent": "Config/1.0 (Test)",
            ]
        )
        let config = ConfigReader(provider: provider, accessReporter: accessReporter)

        _ = config.string(forKey: "http.client.user-agent")
        _ = config.string(forKey: "http.client.user-agent", isSecret: true)
        _ = config.string(forKey: "http.secret")
        _ = config.string(forKey: "http.secret", isSecret: true)

        let events = accessReporter.events
        try #require(events.count == 4)

        try #require(events[0].providerResults.count == 1)
        try #expect(
            events[0].providerResults[0].result.get().value == "Config/1.0 (Test)"
        )
        try #expect(events[0].result.get() == "Config/1.0 (Test)")

        try #require(events[1].providerResults.count == 1)
        try #expect(
            events[1].providerResults[0].result.get().value == ConfigValue("Config/1.0 (Test)", isSecret: true)
        )
        try #expect(events[1].result.get() == ConfigValue("Config/1.0 (Test)", isSecret: true))

        try #require(events[2].providerResults.count == 1)
        try #expect(
            events[2].providerResults[0].result.get().value == ConfigValue("s3cret", isSecret: true)
        )
        try #expect(events[2].result.get() == ConfigValue("s3cret", isSecret: true))

        try #require(events[3].providerResults.count == 1)
        try #expect(
            events[3].providerResults[0].result.get().value == ConfigValue("s3cret", isSecret: true)
        )
        try #expect(events[3].result.get() == ConfigValue("s3cret", isSecret: true))
    }

    @Test func fetch() async throws {
        let accessReporter = TestAccessReporter()
        let provider = InMemoryProvider(
            name: "test",
            values: [
                "http.secret": .init("s3cret", isSecret: true),
                "http.client.user-agent": "Config/1.0 (Test)",
            ]
        )
        let config = ConfigReader(provider: provider, accessReporter: accessReporter)

        _ = try await config.fetchString(forKey: "http.client.user-agent")
        _ = try await config.fetchString(forKey: "http.client.user-agent", isSecret: true)
        _ = try await config.fetchString(forKey: "http.secret")
        _ = try await config.fetchString(forKey: "http.secret", isSecret: true)

        let events = accessReporter.events
        try #require(events.count == 4)

        try #require(events[0].providerResults.count == 1)
        try #expect(
            events[0].providerResults[0].result.get().value == "Config/1.0 (Test)"
        )
        try #expect(events[0].result.get() == "Config/1.0 (Test)")

        try #require(events[1].providerResults.count == 1)
        try #expect(
            events[1].providerResults[0].result.get().value
                == ConfigValue("Config/1.0 (Test)", isSecret: true)
        )
        try #expect(events[1].result.get() == ConfigValue("Config/1.0 (Test)", isSecret: true))

        try #require(events[2].providerResults.count == 1)
        try #expect(
            events[2].providerResults[0].result.get().value == ConfigValue("s3cret", isSecret: true)
        )
        try #expect(events[2].result.get() == ConfigValue("s3cret", isSecret: true))

        try #require(events[3].providerResults.count == 1)
        try #expect(
            events[3].providerResults[0].result.get().value == ConfigValue("s3cret", isSecret: true)
        )
        try #expect(events[3].result.get() == ConfigValue("s3cret", isSecret: true))
    }

    @Test func watch() async throws {
        let accessReporter = TestAccessReporter()
        let provider = InMemoryProvider(
            name: "test",
            values: [
                "http.secret": .init("s3cret", isSecret: true),
                "http.client.user-agent": "Config/1.0 (Test)",
            ]
        )
        let config = ConfigReader(provider: provider, accessReporter: accessReporter)

        _ = try await config.watchString(forKey: "http.client.user-agent") { await $0.first }
        _ = try await config.watchString(forKey: "http.client.user-agent", isSecret: true) { await $0.first }
        _ = try await config.watchString(forKey: "http.secret") { await $0.first }
        _ = try await config.watchString(forKey: "http.secret", isSecret: true) { await $0.first }

        let events = accessReporter.events
        try #require(events.count == 4)

        try #require(events[0].providerResults.count == 1)
        try #expect(
            events[0].providerResults[0].result.get().value == "Config/1.0 (Test)"
        )
        try #expect(events[0].result.get() == "Config/1.0 (Test)")

        try #require(events[1].providerResults.count == 1)
        try #expect(
            events[1].providerResults[0].result.get().value
                == ConfigValue("Config/1.0 (Test)", isSecret: true)
        )
        try #expect(events[1].result.get() == ConfigValue("Config/1.0 (Test)", isSecret: true))

        try #require(events[2].providerResults.count == 1)
        try #expect(
            events[2].providerResults[0].result.get().value == ConfigValue("s3cret", isSecret: true)
        )
        try #expect(events[2].result.get() == ConfigValue("s3cret", isSecret: true))

        try #require(events[3].providerResults.count == 1)
        try #expect(
            events[3].providerResults[0].result.get().value == ConfigValue("s3cret", isSecret: true)
        )
        try #expect(events[3].result.get() == ConfigValue("s3cret", isSecret: true))
    }
}
