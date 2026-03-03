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

import Configuration
import Hummingbird
import HummingbirdTesting
import Logging
import Testing
import Foundation

@testable import App

func initialProviders() -> [(any ConfigProvider)] {
    guard let appSettingsPath = Bundle.module.path(forResource: "appsettings", ofType: "yaml") else {
        fatalError("Unable to find appsettings.yaml in test bundle")
    }
    return [
        InMemoryProvider(values: [
            "http.host": ConfigValue("127.0.0.1"),
            "http.port": ConfigValue(8080),
            "log.level": ConfigValue("trace"),
            "config.filePath": ConfigValue(stringLiteral: appSettingsPath),
            "app.name": ConfigValue("Test"),
        ])
    ]
}

@Suite
struct AppTests {
    @Test
    func app() async throws {
        let app = try await buildApplication(initialConfigProviders: initialProviders())
        try await app.test(.router) { client in
            try await client.execute(uri: "/", method: .get) { response in
                #expect(String(buffer: response.body) == "Hello Test!")
            }
        }
    }
}
