import Configuration
import Hummingbird
import Logging

// Request context used by application
typealias AppRequestContext = BasicRequestContext

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
    
    let router = try buildRouter(config: reader, dynamicConfig: dynamicConfigReader)

    // Create the app and add a service to it.
    // https://docs.hummingbird.codes/2.0/documentation/hummingbird/servicelifecycle#Hummingbird-Integration
    let app = Application(
        router: router,
        configuration: ApplicationConfiguration(reader: reader.scoped(to: "http")),
        services: [dynamicConfig],
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
    router.get("/") { _,_ in
        let name = dynamicConfig.string(forKey: "name")

        return "Hello \(name ?? "World")!"
    }
    return router
}
