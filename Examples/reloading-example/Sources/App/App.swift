import Configuration
import Hummingbird
import Logging

@main
struct App {
    static func main() async throws {
        // Application will read configuration from the following in the order listed
        // Command line, Environment variables, dotEnv file, defaults provided in memory
        // CLI >overrides> ENV >overrides> .env >overrides> in-memory defaults

        let reader = try await ConfigReader(providers: [
            CommandLineArgumentsProvider(),
            EnvironmentVariablesProvider(),
            EnvironmentVariablesProvider(environmentFilePath: ".env", allowMissing: true),
            InMemoryProvider(values: [
                "log.level": "info",
                "filePath": "/etc/config/appsettings.json", // the default, expected dynamic configuration location
                "pollIntervalSeconds": 1, // default reload interval is 15 seconds, set to 1 second for the example
                "http.serverName": "config-reload-example"
            ])
        ])
        let app = try await buildApplication(reader: reader) // <-- this is a service, and you can add other

        try await app.runService()
    }
}
