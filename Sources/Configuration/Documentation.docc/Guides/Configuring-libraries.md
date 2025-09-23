# Configuring libraries

Provide a consistent and flexible way to configure your library.

## Overview

Swift Configuration offers a pattern for configuring libraries that works across various configuration sources: be it from environment variables, a JSON file, or a remote configuration service. 

This guide shows how to adopt this pattern in your own library, to make it easier to compose in a larger application.

Adopt this pattern in three steps:

1. Define your library's configuration as a dedicated type (you might already have such a type in your library).
2. Add a convenience method that accepts a ``ConfigReader`` - can be an initializer, or a method that updates your configuration.
3. Extract the individual configuration values using the provided reader.

This approach makes your library configurable regardless of the user's chosen configuration source and composes well with other libraries.

### Define your configuration type

Start by defining a type that encapsulates all the configuration options for your library.

```swift
/// Configuration options for a hypothetical HTTPClient.
public struct HTTPClientConfiguration {
    /// The timeout for network requests in seconds.
    public var timeout: Double

    /// The maximum number of concurrent connections.
    public var maxConcurrentConnections: Int

    /// Base URL for API requests.
    public var baseURL: String

    /// Whether to enable debug logging.
    public var debugLogging: Bool

    /// Create a configuration with explicit values.
    public init(
        timeout: Double = 30.0,
        maxConcurrentConnections: Int = 5,
        baseURL: String = "https://api.example.com",
        debugLogging: Bool = false
    ) {
        self.timeout = timeout
        self.maxConcurrentConnections = maxConcurrentConnections
        self.baseURL = baseURL
        self.debugLogging = debugLogging
    }
}
```

### Add a convenience method

Next, extend your configuration type to provide a method that accepts a ``ConfigReader`` as a parameter. In the example below, we use an initializer.

```swift
extension HTTPClientConfiguration {
    /// Creates a new HTTP client configuration using values from the provided reader.
    ///
    /// ## Configuration keys
    /// - `timeout` (double, optional, default: `30.0`): The timeout for network requests in seconds.
    /// - `maxConcurrentConnections` (int, optional, default: `5`): The maximum number of concurrent connections.
    /// - `baseURL` (string, optional, default: `"https://api.example.com"`): Base URL for API requests.
    /// - `debugLogging` (bool, optional, default: `false`): Whether to enable debug logging.
    ///
    /// - Parameter config: The config reader to read configuration values from.
    public init(config: ConfigReader) {
        self.timeout = config.double(forKey: "timeout", default: 30.0)
        self.maxConcurrentConnections = config.int(forKey: "maxConcurrentConnections", default: 5)
        self.baseURL = config.string(forKey: "baseURL", default: "https://api.example.com")
        self.debugLogging = config.bool(forKey: "debugLogging", default: false)
    }
}
```

> Tip: To make it easier for your library's adopters to configure their application, document the configuration values your convenience method is extracting, like in the example above.

### Example: Adopting your library

Once you've made your library configurable, users can easily configure it from various sources. Here's how someone might configure your library using environment variables:

```swift
import Configuration
import YourHTTPLibrary

// Create a config reader from environment variables.
let config = ConfigReader(provider: EnvironmentVariablesProvider())

// Initialize your library's configuration from a config reader.
let httpConfig = HTTPClientConfiguration(config: config)

// Create your library instance with the configuration.
let httpClient = HTTPClient(configuration: httpConfig)

// Start using your library.
httpClient.get("/users") { response in
    // Handle the response.
}
```

With this approach, users can configure your library by setting environment variables that match your config keys:

```bash
# Set configuration for your library through environment variables.
export TIMEOUT=60.0
export MAX_CONCURRENT_CONNECTIONS=10
export BASE_URL="https://api.production.com"
export DEBUG_LOGGING=true
```

Your library now adapts to the user's environment without any code changes.

### Working with secrets

Mark configuration values that contain sensitive information as secret to prevent them from being logged:

```swift
extension HTTPClientConfiguration {
    public init(config: ConfigReader) throws {
        self.apiKey = try config.requiredString(forKey: "apiKey", isSecret: true)
        // Other configuration...
    }
}
```

Built-in ``AccessReporter`` types such as ``AccessLogger`` and ``FileAccessLogger`` automatically redact secret values to avoid leaking sensitive information.

For more guidance on secrets handling, see <doc:Handling-secrets-correctly>. For comprehensive configuration best practices, check out <doc:Best-practices>. To understand different access patterns and reader methods, refer to <doc:Choosing-access-patterns> and <doc:Choosing-reader-methods>.
