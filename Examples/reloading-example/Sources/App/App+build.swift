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
import ServiceLifecycle

// Request context used by application
typealias AppRequestContext = BasicRequestContext

struct ConfigWatchReporter: Service {
    let config: ConfigReader
    let logger: Logger

    func run() async throws {
        try await self.config.scoped(to: "app")
            .watchString(forKey: "name", default: "unset") { updates in
                for try await update in updates.cancelOnGracefulShutdown() {
                    logger.info("Received a configuration change: \(update)")
                }
            }
    }
}

/// Builds the application.
/// - Parameter initialConfigProviders: A set of initial configuration providers
/// - Throws: Configuration or application setup errors.
/// - Returns: Configured application instance.
func buildApplication(initialConfigProviders: [(any ConfigProvider)]) async throws
    -> some ApplicationProtocol
{

    // Create an initial configuration reader to bootstrap readers that depend on it,
    // such as a ReloadingFileProvider, and setting up logging.
    let initConfig = ConfigReader(providers: initialConfigProviders)

    let logger = {
        var logger = Logger(label: initConfig.string(forKey: "http.serverName", default: "default-HB-server"))
        logger.logLevel = initConfig.string(forKey: "log.level", as: Logger.Level.self, default: .info)
        return logger
    }()

    // https://swiftpackageindex.com/apple/swift-configuration/documentation/configuration
    // Create a dynamic configuration provider that watches a file for changes and reloads it when it
    // changes the file path and polling interval are read from the initial configuration reader.
    let reloadingProvider: ReloadingFileProvider<YAMLSnapshot> = try await ReloadingFileProvider<YAMLSnapshot>(
        config: initConfig.scoped(to: "config")
    )
    // Assemble a final configuration reader that includes the dynamic provider
    let config = ConfigReader(
        providers: [reloadingProvider] + initialConfigProviders,
        accessReporter: AccessLogger(logger: logger)
    )

    let configReporter = ConfigWatchReporter(config: config, logger: logger)

    // Assemble the routes for the app.
    let router = try buildRouter(config: config)

    // Create the app and add the services to it.
    // https://docs.hummingbird.codes/2.0/documentation/hummingbird/servicelifecycle#Hummingbird-Integration
    // This runs a background service that watches for fileystem changes for configuration, and another
    // that reports changes to a specific configuration value.
    let app = Application(
        router: router,
        configuration: ApplicationConfiguration(reader: config.scoped(to: "http")),
        services: [
            reloadingProvider,
            configReporter,
        ],
        logger: logger
    )
    return app
}

/// Builds the router.
/// - Parameter config: Configuration for the app.
/// - Throws: Configuration or setup errors.
/// - Returns: The configured router for the app.
func buildRouter(config: ConfigReader) throws -> Router<AppRequestContext> {
    let router = Router(context: AppRequestContext.self)
    // Add middleware
    router.addMiddleware {
        // logging middleware
        LogRequestsMiddleware(config.string(forKey: "log.level", as: Logger.Level.self, default: .info))
    }
    // Add default endpoint
    router.get("/") { _, _ in
        let name = config.scoped(to: "app").string(forKey: "name")

        return "Hello \(name ?? "World")!"
    }
    return router
}
