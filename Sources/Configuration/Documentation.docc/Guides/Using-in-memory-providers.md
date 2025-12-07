# Using in-memory providers

Learn about the ``InMemoryProvider`` and ``MutableInMemoryProvider`` built-in types.

## Overview

Swift Configuration provides two in-memory providers, which are directly instantiated with the desired keys and values, rather than being parsed from another representation. These providers are particularly useful for testing, providing fallback values, and bridging with other configuration systems.

- ``InMemoryProvider`` is an immutable value type, and can be useful for defining overrides and fallbacks in a provider hierarchy.
- ``MutableInMemoryProvider`` is a mutable reference type, allowing you to update values and get any watchers notified automatically. It can be used to bridge from other stateful, callback-based configuration sources.

### InMemoryProvider

The ``InMemoryProvider`` is ideal for static configuration values that don't change during application runtime.

#### Basic usage

Create an ``InMemoryProvider`` with a dictionary of configuration values:

```swift
let provider = InMemoryProvider(values: [
    "database.host": "localhost",
    "database.port": 5432,
    "api.timeout": 30.0,
    "debug.enabled": true
])

let config = ConfigReader(provider: provider)
let host = config.string(forKey: "database.host") // "localhost"
let port = config.int(forKey: "database.port") // 5432
```

#### Using with hierarchical keys

You can use ``AbsoluteConfigKey`` for more complex key structures:

```swift
let provider = InMemoryProvider(values: [
    AbsoluteConfigKey(["http", "client", "timeout"]): 30.0,
    AbsoluteConfigKey(["http", "server", "port"]): 8080,
    AbsoluteConfigKey(["logging", "level"]): "info"
])
```

#### Configuration context

The in-memory provider performs exact matching of config keys, including the context. This allows you to provide different values for the same key path based on contextual information.

The following example shows using two keys with the same key path, but different context, and giving them two different values:

```swift
let provider = InMemoryProvider(
    values: [
        AbsoluteConfigKey(
            ["http", "client", "timeout"], 
            context: ["upstream": "example1.org"]
        ): 15.0,
        AbsoluteConfigKey(
            ["http", "client", "timeout"], 
            context: ["upstream": "example2.org"]
        ): 30.0,
    ]
)
```

With a provider configured this way, a config reader will return the following results:

```swift
let config = ConfigReader(provider: provider)
config.double(forKey: "http.client.timeout") // nil
config.double(
    forKey: ConfigKey(
        "http.client.timeout", 
        context: ["upstream": "example1.org"]
    )
) // 15.0
config.double(
    forKey: ConfigKey(
        "http.client.timeout",
        context: ["upstream": "example2.org"]
    )
) // 30.0
```

### MutableInMemoryProvider

The ``MutableInMemoryProvider`` allows you to modify configuration values at runtime and notify watchers of changes.

#### Basic usage

```swift
let provider = MutableInMemoryProvider()
provider.setValue("localhost", forKey: "database.host")
provider.setValue(5432, forKey: "database.port")

let config = ConfigReader(provider: provider)
let host = config.string(forKey: "database.host") // "localhost"
```

#### Updating values

You can update values after creation, and any watchers will be notified:

```swift
// Initial setup
provider.setValue("debug", forKey: "logging.level")

// Later in your application, watchers are notified
provider.setValue("info", forKey: "logging.level") 
```

#### Watching for changes

Use the provider's async sequence to watch for configuration changes:

```swift
let config = ConfigReader(provider: provider)
try await config.watchString(
    forKey: "logging.level",
    as: Logger.Level.self,
    default: .debug
) { updates in
    for try await level in updates {
        print("Logging level changed to: \(level)")
    }
}
```

### Common Use Cases

#### Testing

In-memory providers are excellent for unit testing:

```swift
func testDatabaseConnection() {
    let testProvider = InMemoryProvider(values: [
        "database.host": "test-db.example.com",
        "database.port": 5433,
        "database.name": "test_db"
    ])
    
    let config = ConfigReader(provider: testProvider)
    let connection = DatabaseConnection(config: config)
    // Test your database connection logic
}
```

#### Fallback values

Use ``InMemoryProvider`` as a fallback in a provider hierarchy:

```swift
let fallbackProvider = InMemoryProvider(values: [
    "api.timeout": 30.0,
    "retry.maxAttempts": 3,
    "cache.enabled": true
])

let config = ConfigReader(providers: [
    EnvironmentVariablesProvider(),
    fallbackProvider 
    // Used when environment variables are not set
])
```

#### Bridging other systems

Use ``MutableInMemoryProvider`` to bridge configuration from other systems:

```swift
class ConfigurationBridge {
    private let provider = MutableInMemoryProvider()
    
    func updateFromExternalSystem(_ values: [String: ConfigValue]) {
        for (key, value) in values {
            provider.setValue(value, forKey: key)
        }
    }
}
```

For comparison with reloading providers, see <doc:Using-reloading-providers>. To understand different access patterns and when to use each provider type, check out <doc:Choosing-access-patterns>. For more configuration guidance, refer to <doc:Best-practices>.
