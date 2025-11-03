# Choosing the access pattern

Learn how to select the right method for reading configuration values based on your needs.

## Overview

Swift Configuration provides three access patterns for retrieving configuration values, each optimized 
for different use cases and performance requirements.

The three access patterns are:

- **Get**: Synchronous access to current values available locally, in-memory.
- **Fetch**: Asynchronous access to retrieve fresh values from authoritative sources, optionally with extra context.
- **Watch**: Reactive access that provides real-time updates when values change.

> Tip: Start with the "get" pattern, and only explore "fetch" and "watch" patterns if needed.

### Get: Synchronous local access

The "get" pattern provides immediate, synchronous access to configuration values that are already available in memory.
This is the fastest and most commonly used access pattern.

```swift
let config = ConfigReader(provider: EnvironmentVariablesProvider())

// Get the current timeout value synchronously
let timeout = config.int(forKey: "http.timeout", default: 30)

// Get a required value that must be present
let apiKey = try config.requiredString(forKey: "api.key", isSecret: true)
```

#### When to use

Use the "get" pattern when:

- **Performance is critical**: You need immediate access without async overhead.
- **Values are stable**: Configuration doesn't change frequently during runtime.
- **Simple providers**: Using environment variables, command-line arguments, or files.
- **Startup configuration**: Reading values during application initialization.
- **Request handling**: Accessing configuration in hot code paths where async calls would add latency.

#### Behavior characteristics

- Returns the currently cached value from the provider.
- No network or I/O operations occur during the call.
- Values may become stale if the underlying data source changes and the provider is either non-reloading, or 
  has a long reload interval.

### Fetch: Asynchronous fresh access

The "fetch" pattern asynchronously retrieves the most current value from the authoritative data source. This ensures 
you always get up-to-date configuration, even if it requires network calls or file system access.

```swift
let config = ConfigReader(provider: remoteConfigProvider)

// Fetch the latest timeout from a remote configuration service
let timeout = try await config.fetchInt(forKey: "http.timeout", default: 30)

// Fetch with context for environment-specific configuration
let dbConnectionString = try await config.fetchRequiredString(
    forKey: "database.url",
    context: [
        "environment": "production",
        "region": "us-west-2",
        "service": "user-service"
    ],
    isSecret: true
)
```

#### When to use

Use the `fetch` pattern when:

- **Freshness is critical**: You need the latest configuration values.
- **Remote providers**: Using configuration services, databases, or external APIs that perform evaluation remotely.
- **Infrequent access**: Reading configuration occasionally, not in hot paths.
- **Setup operations**: Configuring long-lived resources like database connections where one-time overhead isn't 
  a concern, and the improved freshness is important.
- **Administrative operations**: Fetching current settings for management interfaces.

#### Behavior characteristics

- Always contacts the authoritative data source.
- May involve network calls, file system access, or database queries.
- Providers may (but are not required to) cache the fetched value for subsequent "get" calls.
- Throws an error if the provider fails to reach the source.

### Watch: Reactive continuous updates

The "watch" pattern provides an async sequence of configuration updates, allowing you to react to changes in real-time.
This is ideal for long-running services that need to adapt to configuration changes without restarting.

The async sequence is required to receive the current value as the first element as quickly as possible - this is 
part of the API contract with configuration providers (for details, check out ``ConfigProvider``.)

```swift
let config = ConfigReader(provider: reloadingProvider)

// Watch for timeout changes and update connection pools
try await config.watchInt(forKey: "http.timeout", default: 30) { updates in
    for await newTimeout in updates {
        print("HTTP timeout updated to: \(newTimeout)")
        connectionPool.updateTimeout(newTimeout)
    }
}
```

#### When to use

Use the "watch" pattern when:

- **Dynamic configuration**: Values change during application runtime.
- **Hot reloading**: Need to update behavior without restarting the service.
- **Feature toggles**: Enabling/disabling features based on configuration changes.
- **Resource management**: Adjusting timeouts, limits, or thresholds dynamically.
- **A/B testing**: Updating experimental parameters in real-time.

#### Behavior characteristics

- Immediately emits the initial value, then subsequent updates.
- Continues monitoring until the task is cancelled.
- Works with providers like ``ReloadingFileProvider``.

For details on reloading providers, check out <doc:Using-reloading-providers>.

### Using configuration context

All access patterns support configuration context, which provides additional metadata to help providers return 
more specific values. Context is particularly useful with the "fetch" and "watch" patterns when working with 
dynamic or environment-aware providers.

#### Filtering watch updates using context

```swift
let context: [String: ConfigContextValue] = [
    "environment": "production",
    "region": "us-east-1", 
    "service_version": "2.1.0",
    "feature_tier": "premium",
    "load_factor": 0.85
]

// Get environment-specific database configuration
let dbConfig = try await config.fetchRequiredString(
    forKey: "database.connection_string",
    context: context,
    isSecret: true
)

// Watch for region-specific timeout adjustments
try await config.watchInt(
    forKey: "api.timeout",
    context: ["region": "us-west-2"],
    default: 5000
) { updates in
    for await timeout in updates {
        apiClient.updateTimeout(milliseconds: timeout)
    }
}
```

### Summary of performance considerations

#### Get pattern performance
- **Fastest**: No async overhead, immediate return.
- **Memory usage**: Minimal, uses cached values.
- **Best for**: Request handling, hot code paths, startup configuration.

#### Fetch pattern performance  
- **Moderate**: Async overhead plus data source access time.
- **Network dependent**: Performance varies with provider implementation.
- **Best for**: Infrequent access, setup operations, administrative tasks.

#### Watch pattern performance
- **Background monitoring**: Continuous resource usage for monitoring.
- **Event-driven**: Efficient updates only when values change.
- **Best for**: Long-running services, dynamic configuration, feature toggles.

### Error handling strategies

Each access pattern handles errors differently:

#### Get pattern errors
```swift
// Returns nil or default value for missing/invalid config
let timeout = config.int(forKey: "http.timeout", default: 30)

// Required variants throw errors for missing values
do {
    let apiKey = try config.requiredString(forKey: "api.key")
} catch {
    // Handle missing required configuration
}
```

#### Fetch pattern errors
```swift
// All fetch methods propagate provider and conversion errors
do {
    let config = try await config.fetchRequiredString(forKey: "database.url")
} catch {
    // Handle network errors, missing values, or conversion failures
}
```

#### Watch pattern errors
```swift
// Errors appear in the async sequence
try await config.watchRequiredInt(forKey: "port") { updates in
    do {
        for try await port in updates {
            server.updatePort(port)
        }
    } catch {
        // Handle provider errors or missing required values
    }
}
```

### Best practices

1. **Choose based on use case**: Use "get" for performance-critical paths, "fetch" for freshness, and 
   "watch" for hot reloading.

2. **Handle errors appropriately**: Design error handling strategies that match your application's 
   resilience requirements.

3. **Use context judiciously**: Provide context when you need environment-specific or conditional 
   configuration values.

4. **Monitor configuration access**: Use ``AccessReporter`` to understand your application's 
   configuration dependencies.

5. **Cache wisely**: For frequently accessed values, prefer "get" over repeated "fetch" calls.

For more guidance on selecting the right reader methods for your needs, see <doc:Choosing-reader-methods>. 
To learn about handling sensitive configuration values securely, check out <doc:Handling-secrets-correctly>. 
If you encounter issues with configuration access, refer to <doc:Troubleshooting> for debugging techniques.
