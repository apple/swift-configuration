import Configuration
import Hummingbird
import Logging
import ServiceLifecycle

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

// Request context used by application
typealias AppRequestContext = BasicRequestContext

struct ConfigWatchReporter: Service {
    let dynamicConfig: ConfigReader
    let logger: Logger

    init(dynamicConfig: ConfigReader, logger: Logger) {
        self.dynamicConfig = dynamicConfig
        self.logger = logger
    }

    func run() async throws {
        try await self.dynamicConfig.watchString(forKey: "name", default: "unset") { updates in
            for try await update in updates {
                logger.info("Received a configuration change: \(update)")
            }
        }
    }
}

///  Build application
/// - Parameter reader: configuration reader
func buildApplication(reader: ConfigReader) async throws -> some ApplicationProtocol {
    let logger = {
        var logger = Logger(label: reader.string(forKey: "http.serverName", default: "default-HB-server"))
        logger.logLevel = reader.string(forKey: "log.level", as: Logger.Level.self, default: .info)
        return logger
    }()

    // https://swiftpackageindex.com/apple/swift-configuration/1.0.1/documentation/configuration
    let dynamicConfig = try await ReloadingFileProvider<YAMLSnapshot>(config: reader)

    let dynamicConfigReader = ConfigReader(provider: dynamicConfig)
    let configReporter = ConfigWatchReporter(dynamicConfig: dynamicConfigReader, logger: logger)

    let router = try buildRouter(config: reader, dynamicConfig: dynamicConfigReader)

    // Create the app and add a service to it.
    // https://docs.hummingbird.codes/2.0/documentation/hummingbird/servicelifecycle#Hummingbird-Integration
    let app = Application(
        router: router,
        configuration: ApplicationConfiguration(reader: reader.scoped(to: "http")),
        services: [dynamicConfig, configReporter],
        logger: logger
    )
    return app
}

/// Build router
func buildRouter(config: ConfigReader, dynamicConfig: ConfigReader) throws -> Router<AppRequestContext> {
    let router = Router(context: AppRequestContext.self)
    // Add middleware
    router.addMiddleware {
        // logging middleware
        LogRequestsMiddleware(config.string(forKey: "log.level", as: Logger.Level.self, default: .info))
    }
    // Add default endpoint
    router.get("/") { _, _ in
        let name = dynamicConfig.string(forKey: "name")

        return "Hello \(name ?? "World")!"
    }
    return router
}
