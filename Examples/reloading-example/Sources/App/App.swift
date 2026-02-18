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
import Logging

@main
struct App {
    static func main() async throws {
        // Application will read configuration from the following in the order listed
        // Command line, Environment variables, dotEnv file, defaults provided in memory
        // CLI >overrides> ENV >overrides> .env >overrides> in-memory defaults
        async let staticProviders: [(any ConfigProvider)] = [
            CommandLineArgumentsProvider(),
            EnvironmentVariablesProvider(),
            EnvironmentVariablesProvider(environmentFilePath: ".env", allowMissing: true),
            InMemoryProvider(values: [
                // default log level
                "log.level": "info",

                // the default, expected dynamic configuration location
                "config.filePath": "/etc/config/appsettings.yaml",

                // default reload interval is 15 seconds, set to 1 second for the example
                "pollIntervalSeconds": 1,

                //name used in the logger
                "http.serverName": "config-reload-example",
            ]),
        ]
        // create an initial configuration reader to bootstrap readers that depend on it, such as a ReloadingFileProvider
        let initConfig = try await ConfigReader(providers: staticProviders)

        // https://swiftpackageindex.com/apple/swift-configuration/documentation/configuration
        // create a dynamic configuration provider that watches a file for changes and reloads it when it changes
        // the file path and polling interval are read from the initial configuration reader
        let dynamicConfig = try await ReloadingFileProvider<YAMLSnapshot>(config: initConfig.scoped(to: "config"))
        // assemble a final configuration reader that includes the dynamic provider
        let config = try await ConfigReader(providers: [dynamicConfig] + staticProviders)

        let app = try await buildApplication(config: config)

        try await app.runService()
    }
}
