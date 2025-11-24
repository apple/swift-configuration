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

import Configuration
import Testing
import ConfigurationTestingInternal

struct ConfigSnapshotReaderTests {

    @available(Configuration 1.0, *)
    @Test func get() throws {
        let provider = InMemoryProvider(
            name: "test",
            values: [
                "http.client.user-agent": "Config/1.0 (Test)"
            ]
        )
        let config = ConfigReader(provider: provider)
        let snapshot = config.snapshot()
        try #require(snapshot.string(forKey: "http.stuff", default: "test") == "test")
        try #require(snapshot.string(forKey: "http.client.user-agent") == "Config/1.0 (Test)")
    }

    @available(Configuration 1.0, *)
    @Test func watch() async throws {
        let provider = InMemoryProvider(
            name: "test",
            values: [
                "http.client.user-agent": "Config/1.0 (Test)"
            ]
        )
        let config = ConfigReader(provider: provider)
        try await config.watchSnapshot { updates in
            for try await snapshot in updates {
                try #require(snapshot.string(forKey: "http.stuff", default: "test") == "test")
                try #require(snapshot.string(forKey: "http.client.user-agent") == "Config/1.0 (Test)")
                break
            }
        }
    }

    @available(Configuration 1.0, *)
    @Test func scoping() throws {
        let provider = InMemoryProvider(
            name: "test",
            values: [
                "http.client.user-agent": "Config/1.0 (Test)"
            ]
        )
        let config = ConfigReader(provider: provider)
        let snapshot = config.snapshot()
        #expect(snapshot.string(forKey: "user-agent") == nil)
        let scoped = snapshot.scoped(to: "http.client")
        #expect(scoped.string(forKey: "user-agent") == "Config/1.0 (Test)")
    }

    @available(Configuration 1.0, *)
    @Test func scopingCustomDecoder() throws {
        let provider = InMemoryProvider(
            name: "test",
            values: [
                "http.client.user-agent": "Config/1.0 (Test)"
            ]
        )
        let config = ConfigReader(provider: provider)
        let snapshot = config.snapshot()
        let scoped = snapshot.scoped(to: "http", keyDecoderOverride: .colonSeparated)
        #expect(scoped.string(forKey: "client:user-agent") == "Config/1.0 (Test)")
    }
}
