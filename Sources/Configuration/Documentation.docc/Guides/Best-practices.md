# Adopting best practices

Follow these principles to make your code easily configurable and composable with other libraries.

## Overview

When designing configuration for Swift libraries and applications, follow these patterns to create consistent, maintainable code that integrates well with the Swift ecosystem.

### Document configuration keys

Include thorough documentation about what configuration keys your library reads. For each key, document:

- The key name and its hierarchical structure.
- The expected data type.
- Whether the key is required or optional.
- Default values when applicable.
- Valid value ranges or constraints.
- Usage examples.

```swift
public struct HTTPClientConfiguration {
    /// ...
    ///
    /// ## Configuration keys:
    /// - `timeout` (double, optional, default: 30.0): Request timeout in seconds.
    /// - `maxRetries` (int, optional, default: 3, range: 0-10): Maximum retry attempts.
    /// - `baseURL` (string, required): Base URL for requests.
    /// - `apiKey` (string, required, secret): API authentication key.
    ///
    /// ...
    public init(config: ConfigReader) {
        // Implementation...
    }
}
```

### Use sensible defaults

Provide reasonable default values to make your library work without extensive configuration.

```swift
// Good: Provides sensible defaults
let timeout = config.double(forKey: "http.timeout", default: 30.0)
let maxConnections = config.int(forKey: "http.maxConnections", default: 10)

// Avoid: Requiring configuration for common scenarios
let timeout = try config.requiredDouble(forKey: "http.timeout") // Forces users to configure
```

### Use scoped configuration

Organize your configuration keys logically using namespaces to keep related keys together.

```swift
// Good:
let httpConfig = config.scoped(to: "http")
let timeout = httpConfig.double(forKey: "timeout", default: 30.0)
let retries = httpConfig.int(forKey: "retries", default: 3)

// Better (in libraries): Offer a convenience method that reads your library's configuration.
// Tip: Read the configuration values from the provided reader directly, do not scope it
// to a "myLibrary" namespace. Instead, let the caller of MyLibraryConfiguration.init(config:)
// perform any scoping for your library's configuration.
public struct MyLibraryConfiguration {
    public init(config: ConfigReader) {
        self.timeout = config.double(forKey: "timeout", default: 30.0)
        self.retries = config.int(forKey: "retries", default: 3)
    }
}

// Called from an app - the caller is responsible for adding a namespace and naming it, if desired.
let libraryConfig = MyLibraryConfiguration(config: config.scoped(to: "myLib"))
```

> See also: For more guidance on making your library configurable, check out <doc:Configuring-libraries>.

### Mark secrets appropriately

Mark sensitive configuration values like API keys, passwords, or tokens as secrets using the `isSecret: true` parameter.
This tells access reporters to redact those values in logs.

```swift
// Mark sensitive values as secrets
let apiKey = try config.requiredString(forKey: "api.key", isSecret: true)
let password = config.string(forKey: "database.password", default: nil, isSecret: true)

// Regular values don't need the isSecret parameter
let timeout = config.double(forKey: "api.timeout", default: 30.0)
```

Some providers also support the ``SecretsSpecifier``, allowing you to mark which values are secret 
during application bootstrapping.

For comprehensive guidance on handling secrets securely, see <doc:Handling-secrets-correctly>.

### Prefer optional over required

Only mark configuration as required if your library absolutely cannot function without it. For most cases, 
provide sensible defaults and make configuration optional.

```swift
// Good: Optional with sensible defaults
let timeout = config.double(forKey: "timeout", default: 30.0)
let debug = config.bool(forKey: "debug", default: false)

// Use required only when absolutely necessary
let apiEndpoint = try config.requiredString(forKey: "api.endpoint")
```

For more details, check out <doc:Choosing-reader-methods>.

### Validate configuration values

Validate configuration values and throw meaningful errors for invalid input to catch configuration issues early.

```swift
public init(config: ConfigReader) throws {
    let timeout = config.double(forKey: "timeout", default: 30.0)
    guard timeout > 0 else {
        throw MyConfigurationError.invalidTimeout("Timeout must be positive, got: \(timeout)")
    }

    let maxRetries = config.int(forKey: "maxRetries", default: 3)
    guard maxRetries >= 0 && maxRetries <= 10 else {
        throw MyConfigurationError.invalidRetryCount("Max retries must be 0-10, got: \(maxRetries)")
    }

    self.timeout = timeout
    self.maxRetries = maxRetries
}
```

### Choosing provider types

#### When to use reloading providers

Use reloading providers when you need configuration changes to take effect without restarting your application:

- Long-running services that can't be restarted frequently.
- Development environments where you iterate on configuration.
- Applications that receive configuration updates through file deployments.

Check out <doc:Using-reloading-providers> to learn more.

#### When to use static providers

Use static providers when configuration doesn't change during runtime:

- Containerized applications with immutable configuration.
- Applications where configuration is set once at startup.

#### When to create custom providers

If none of the providers (built-in or community ones) meet your needs, you can implement your own custom provider. Common scenarios include:

- Integrating with external configuration services.
- Reading from a custom file format.
- Bridging an existing configuration system.

For detailed guidance on implementing custom providers, see <doc:Implementing-a-provider>.

For help choosing between different access patterns and reader method variants, see <doc:Choosing-access-patterns>
and <doc:Choosing-reader-methods>. For troubleshooting configuration issues, refer to <doc:Troubleshooting>.
