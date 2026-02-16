# Choosing reader methods

Choose between optional, default, and required variants of configuration methods.

## Overview

For every configuration access pattern (get, fetch, watch) and data type, Swift Configuration provides 
three method variants that handle missing or invalid values differently:

- **Optional variant**: Returns `nil` when a value is missing or cannot be converted.
- **Default variant**: Returns a fallback value when a value is missing or cannot be converted.
- **Required variant**: Throws an error when a value is missing or cannot be converted.

Understanding these variants helps you write robust configuration code that handles missing values appropriately 
for your use case.

> Tip: Start with the "default" variant and only use "optional" or "required" if needed.

### Optional variants

Optional variants return `nil` when a configuration value is missing or cannot be converted to the expected type. 
These methods have the simplest signatures and are ideal when configuration values are truly optional.

```swift
let config = ConfigReader(provider: EnvironmentVariablesProvider())

// Optional get
let timeout: Int? = config.int(forKey: "http.timeout")
let apiUrl: String? = config.string(forKey: "api.url")

// Optional fetch
let latestTimeout: Int? = try await config.fetchInt(forKey: "http.timeout")

// Optional watch
try await config.watchInt(forKey: "http.timeout") { updates in
    for await timeout in updates {
        if let timeout = timeout {
            print("Timeout is set to: \(timeout)")
        } else {
            print("No timeout configured")
        }
    }
}
```

#### When to use

Use optional variants when:

- **Truly optional features**: The configuration controls optional functionality.
- **Gradual rollouts**: New configuration that might not be present everywhere.
- **Conditional behavior**: Your code can operate differently based on presence or absence.
- **Debugging and diagnostics**: You want to detect missing configuration explicitly.

#### Error handling behavior

Optional variants handle errors gracefully by returning `nil`:

- Missing values return `nil`.
- Type conversion errors return `nil`.
- Provider errors return `nil` (except for fetch variants, which always propagate provider errors).

```swift
// These all return nil instead of throwing
let missingPort = config.int(forKey: "nonexistent.port") // nil
let invalidPort = config.int(forKey: "invalid.port.value") // nil (if value can't convert to Int)
let failingPort = config.int(forKey: "provider.error.key") // nil (if provider fails)

// Fetch variants still throw provider errors
do {
    let port = try await config.fetchInt(forKey: "network.error") // Throws provider error
} catch {
    // Handle network or provider errors
}
```

### Default variants

Default variants return a specified fallback value when a configuration value is missing or cannot be converted. 
These provide guaranteed non-optional results while handling missing configuration gracefully.

```swift
let config = ConfigReader(provider: EnvironmentVariablesProvider())

// Default get
let timeout = config.int(forKey: "http.timeout", default: 30)
let retryCount = config.int(forKey: "network.retries", default: 3)

// Default fetch
let latestTimeout = try await config.fetchInt(forKey: "http.timeout", default: 30)

// Default watch
try await config.watchInt(forKey: "http.timeout", default: 30) { updates in
    for await timeout in updates {
        print("Using timeout: \(timeout)") // Always has a value
        connectionManager.setTimeout(timeout)
    }
}
```

#### When to use

Use default variants when:

- **Sensible defaults exist**: You have reasonable fallback values for missing configuration.
- **Simplified code flow**: You want to avoid optional handling in business logic.
- **Required functionality**: The feature needs a value to operate, but can use defaults.
- **Configuration evolution**: New settings that should work with older deployments.

#### Choose good defaults

Consider these principles when choosing default values:

```swift
// Safe defaults that won't cause issues
let timeout = config.int(forKey: "http.timeout", default: 30) // Reasonable timeout
let maxRetries = config.int(forKey: "retries.max", default: 3) // Conservative retry count
let cacheSize = config.int(forKey: "cache.size", default: 1000) // Modest cache size

// Environment-specific defaults
let logLevel = config.string(forKey: "log.level", default: "info") // Safe default level
let enableDebug = config.bool(forKey: "debug.enabled", default: false) // Secure default

// Performance defaults that err on the side of caution
let batchSize = config.int(forKey: "batch.size", default: 100) // Small safe batch
let maxConnections = config.int(forKey: "pool.max", default: 10) // Conservative pool
```

#### Error handling behavior

Default variants handle errors by returning the default value:

- Missing values return the default.
- Type conversion errors return the default.
- Provider errors return the default (except for fetch variants).

### Required variants

Required variants throw errors when configuration values are missing or cannot be converted. These enforce that 
critical configuration must be present and valid.

```swift
let config = ConfigReader(provider: EnvironmentVariablesProvider())

do {
    // Required get
    let serverPort = try config.requiredInt(forKey: "server.port")
    let databaseHost = try config.requiredString(forKey: "database.host")
    
    // Required fetch
    let latestPort = try await config.fetchRequiredInt(forKey: "server.port")
    
    // Required watch
    try await config.watchRequiredInt(forKey: "server.port") { updates in
        for try await port in updates {
            print("Server port updated to: \(port)")
            server.updatePort(port)
        }
    }
} catch {
    fatalError("Configuration error: \(error)")
}
```

#### When to use

Use required variants when:

- **Essential service configuration**: Server ports, database hosts, service endpoints.
- **Application startup**: Values you need before the application can function properly.
- **Critical functionality**: Configuration that must be present for core features to work.
- **Fail-fast behavior**: You want immediate errors for missing critical configuration.

### Choose the right variant

Use this decision tree to select the appropriate variant:

#### Is the configuration value critical for application operation?

**Yes** → Use **required variants**
```swift
// Critical values that must be present
let serverPort = try config.requiredInt(forKey: "server.port")
let databaseHost = try config.requiredString(forKey: "database.host")
```

**No** → Continue to next question

#### Do you have a reasonable default value?

**Yes** → Use **default variants**
```swift
// Optional features with sensible defaults
let timeout = config.int(forKey: "http.timeout", default: 30)
let retryCount = config.int(forKey: "retries", default: 3)
```

**No** → Use **optional variants**
```swift
// Truly optional features where absence is meaningful
let debugEndpoint = config.string(forKey: "debug.endpoint")
let customTheme = config.string(forKey: "ui.theme")
```

### Context and type conversion

All variants support the same additional features:

#### Configuration context
```swift
// Optional with context
let timeout = config.int(
    forKey: ConfigKey(
        "service.timeout",
        context: ["environment": "production", "region": "us-east-1"]
    )
)

// Default with context
let timeout = config.int(
    forKey: ConfigKey(
        "service.timeout",
        context: ["environment": "production"]
    ),
    default: 30
)

// Required with context
let timeout = try config.requiredInt(
    forKey: ConfigKey(
        "service.timeout",
        context: ["environment": "production"]
    )
)
```

#### Type conversion


##### String-representable types

You can automatically convert string configuration values to other types using the `as:` parameter. 
This works with:

**Built-in convertible types:**

- `SystemPackage.FilePath`: Converts from file paths.
- `Foundation.URL`: Converts from URL strings.
- `Foundation.UUID`: Converts from UUID strings.
- `Foundation.Date`: Converts from ISO8601 date strings.

**String-backed enums:**

- Types that conform to `RawRepresentable<String>`.

**Custom types:**

- Types that you explicitly conform to ``ExpressibleByConfigString``.

```swift
// Built-in type conversion
let apiUrl = config.string(forKey: "api.url", as: URL.self)
let requestId = config.string(forKey: "request.id", as: UUID.self)
let configPath = config.string(forKey: "config.path", as: FilePath.self)
let startDate = config.string(forKey: "launch.date", as: Date.self)

// String-backed enum conversion (RawRepresentable<String>)
enum LogLevel: String {
    case debug, info, warning, error
}

// Optional conversion
let level: LogLevel? = config.string(forKey: "log.level", as: LogLevel.self)

// Default conversion
let level = config.string(forKey: "log.level", as: LogLevel.self, default: .info)

// Required conversion
let level = try config.requiredString(forKey: "log.level", as: LogLevel.self)

// Custom type conversion (ExpressibleByConfigString)
struct DatabaseURL: ExpressibleByConfigString {
    let url: URL

    init?(configString: String) {
        guard let url = URL(string: configString) else { return nil }
        self.url = url
    }

    var description: String { url.absoluteString }
}
let dbUrl = config.string(forKey: "database.url", as: DatabaseURL.self)
```

##### Integer-representable types

You can also automatically convert integer configuration values to other types using the `as:` parameter. 
This works with:

**Built-in convertible types:**

- `Swift.Duration`: Converts from an integer value to a duration measured in seconds.

**Int-backed enums:**

- Types that conform to `RawRepresentable<Int>`.

**Custom types:**

- Types that you explicitly conform to ``ExpressibleByConfigInt``.

```swift
// Built-in type conversion
let timeout = config.int(forKey: "api.timeout", as: Duration.self)

// Int-backed enum conversion (RawRepresentable<Int>)
enum LogLevel: Int {
    case error = 1
    case warning = 2
}

// Optional conversion
let level: LogLevel? = config.int(forKey: "log.level", as: LogLevel.self)

// Default conversion
let level = config.int(forKey: "log.level", as: LogLevel.self, default: .error)

// Required conversion
let level = try config.requiredInt(forKey: "log.level", as: LogLevel.self)

// Custom type conversion (ExpressibleByConfigInt)
struct APIVersion: ExpressibleByConfigInt {
    let version: Int

    init?(configInt value: Int) {
        guard value > 0 else { return nil }
        self.version = value
    }

    var description: String { version.description }
}
let apiVersion = config.int(forKey: "api.version", as: APIVersion.self)
```

#### Secret handling

```swift
// Mark sensitive values as secrets in all variants
let optionalKey = config.string(forKey: "api.key", isSecret: true)
let defaultKey = config.string(forKey: "api.key", isSecret: true, default: "development-key")
let requiredKey = try config.requiredString(forKey: "api.key", isSecret: true)
```

Also check out <doc:Handling-secrets-correctly>.

### Best practices

1. **Use required variants** only for truly critical configuration.
2. **Use default variants** for user experience settings where missing configuration shouldn't break functionality.
3. **Use optional variants** for feature flags and debugging where the absence of configuration is meaningful.
4. **Choose safe defaults** that won't cause security issues or performance problems if used in production.

For guidance on selecting between get, fetch, and watch access patterns, see <doc:Choosing-access-patterns>.
For more configuration guidance, check out <doc:Best-practices>.
