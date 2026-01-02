# Configuring applications

Provide flexible and consistent configuration for your application.

## Overview

Swift Configuration provides consistent configuration for your tools and applications. This guide shows how to:

1. Set up a configuration hierarchy with multiple providers.
2. Configure your application's components.
3. Access configuration values in your application and libraries.
4. Monitor configuration access with access reporting.

This pattern works well for server applications where configuration comes from environment variables, configuration files, and remote services.

### Set up a configuration hierarchy

Start by creating a configuration hierarchy in your application's entry point. This defines the order in which configuration sources are consulted when looking for values:

```swift
import Configuration
import Logging

// Create a logger.
let logger: Logger = ...

// Set up the configuration hierarchy: 
// - environment variables first,
//   - then JSON file,
//     - then in-memory defaults.
// Also emit log accesses into the provider logger,
// with secrets automatically redacted.

let config = ConfigReader(
    providers: [
        EnvironmentVariablesProvider(),
        try await FileProvider<JSONSnapshot>(
            filePath: "/etc/myapp/config.json",
            allowMissing: true  // Optional: treat missing file as empty config
        ),
        InMemoryProvider(values: [
            "http.server.port": 8080,
            "http.server.host": "127.0.0.1",
            "http.client.timeout": 30.0
        ])
    ],
    accessReporter: AccessLogger(logger: logger)
)

// Start your application with the config.
try await runApplication(config: config, logger: logger)
```

This configuration hierarchy gives priority to environment variables, then falls back to the JSON file, and finally uses hard-coded default values for any configuration not found in the previous providers.

> Tip: To learn more about access reporting, check out <doc:Troubleshooting>. For more on secrets, check out <doc:Handling-secrets-correctly>.

### Configure your application

Next, configure your application using the configuration reader:

> Note: The `HTTPClientConfiguration` example type is described in <doc:Configuring-libraries>.

```swift
func runApplication(
    config: ConfigReader,
    logger: Logger
) async throws {
    // Get server configuration.
    let serverHost = config.string(
        forKey: "http.server.host",
        default: "localhost"
    )
    let serverPort = config.int(
        forKey: "http.server.port",
        default: 8080
    )

    // Read library configuration with a scoped reader
    // with the prefix `http.client`.
    let httpClientConfig = HTTPClientConfiguration(
        config: config.scoped(to: "http.client")
    )
    let httpClient = HTTPClient(configuration: httpClientConfig)

    // Run your server with the configured components
    try await startHTTPServer(
        host: serverHost,
        port: serverPort,
        httpClient: httpClient,
        logger: logger
    )
}
```

Finally, you configure your application across the three sources. A fully configured set of environment variables could look like the following:

```bash
export HTTP_SERVER_HOST=localhost
export HTTP_SERVER_PORT=8080
export HTTP_CLIENT_TIMEOUT=30.0
export HTTP_CLIENT_MAX_CONCURRENT_CONNECTIONS=20
export HTTP_CLIENT_BASE_URL="https://example.com"
export HTTP_CLIENT_DEBUG_LOGGING=true
```

In JSON:

```json
{
    "http": {
        "server": {
            "host": "localhost",
            "port": 8080
        },
        "client": {
            "timeout": 30.0,
            "maxConcurrentConnections": 20,
            "baseURL": "https://example.com",
            "debugLogging": true
        }
    }
}
```

And using ``InMemoryProvider``:

```swift
[
    "http.server.port": 8080,
    "http.server.host": "127.0.0.1",
    "http.client.timeout": 30.0,
    "http.client.maxConcurrentConnections": 20,
    "http.client.baseURL": "https://example.com",
    "http.client.debugLogging": true,
]
```

In practice, you'd only specify a subset of the config keys in each location, to match the needs of your service's operators.

### Use scoped configuration

For services with multiple instances of the same component, but with different settings, use scoped configuration:

```swift
// For our server example, we might have different API clients
// that need different settings:

let adminConfig = config.scoped(to: "services.admin")
let customerConfig = config.scoped(to: "services.customer")

// Using the admin API configuration
let adminBaseURL = adminConfig.string(
    forKey: "baseURL",
    default: "https://admin-api.example.com"
)
let adminTimeout = adminConfig.double(
    forKey: "timeout",
    default: 60.0
)

// Using the customer API configuration
let customerBaseURL = customerConfig.string(
    forKey: "baseURL",
    default: "https://customer-api.example.com"
)
let customerTimeout = customerConfig.double(
    forKey: "timeout",
    default: 30.0
)
```

You can configure this via environment variables as follows:

```bash
# Admin API configuration
export SERVICES_ADMIN_BASE_URL="https://admin.internal-api.example.com"
export SERVICES_ADMIN_TIMEOUT=120.0
export SERVICES_ADMIN_DEBUG_LOGGING=true

# Customer API configuration
export SERVICES_CUSTOMER_BASE_URL="https://api.example.com"
export SERVICES_CUSTOMER_MAX_CONCURRENT_CONNECTIONS=20
export SERVICES_CUSTOMER_TIMEOUT=15.0
```

For details about the key conversion logic, check out ``EnvironmentVariablesProvider``.

For more configuration guidance, see <doc:Best-practices>. To understand different access patterns and reader methods, refer to <doc:Choosing-access-patterns> and <doc:Choosing-reader-methods>. For handling secrets securely, check out <doc:Handling-secrets-correctly>.
