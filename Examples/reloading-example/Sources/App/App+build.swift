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
        try await self.config.scoped(to: "app").watchString(forKey: "name", default: "unset") { updates in
            for try await update in updates.cancelOnGracefulShutdown() {
                logger.info("Received a configuration change: \(update)")
            }
        }
    }
}

/// Build application.
///
/// - Parameter reader: configuration reader
/// - Throws: Configuration or application setup errors
/// - Returns: Configured application instance
func buildApplication(config: ConfigReader, reloadingProvider: ReloadingFileProvider<YAMLSnapshot>) async throws -> some ApplicationProtocol {
    let logger = {
        var logger = Logger(label: config.string(forKey: "http.serverName", default: "default-HB-server"))
        logger.logLevel = config.string(forKey: "log.level", as: Logger.Level.self, default: .info)
        return logger
    }()

    let configReporter = ConfigWatchReporter(config: config, logger: logger)

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
            configReporter
        ],
        logger: logger
    )
    return app
}

/// Build router.
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
