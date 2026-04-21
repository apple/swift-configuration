# Using reloading providers

Automatically reload configuration from files when they change.

## Overview

A reloading provider monitors configuration files for changes and automatically updates your application's configuration without requiring restarts. Swift Configuration provides:

- ``ReloadingFileProvider`` with ``JSONSnapshot`` for JSON configuration files.
- ``ReloadingFileProvider`` with ``YAMLSnapshot`` for YAML configuration files.

### Basic usage

#### Creating and running providers

Reloading providers run in a [`ServiceGroup`](https://swiftpackageindex.com/swift-server/swift-service-lifecycle/documentation/servicelifecycle/servicegroup):

```swift
import ServiceLifecycle

let provider = try await ReloadingFileProvider<JSONSnapshot>(
    filePath: "/etc/config.json",
    allowMissing: true,  // Optional: treat missing file as empty config
    pollInterval: .seconds(15)
)

let serviceGroup = ServiceGroup(
    services: [provider],
    logger: logger
)

try await serviceGroup.run()
```

#### Reading configuration

Use a reloading provider in the same fashion as a static provider, pass it to a ``ConfigReader``:

```swift
let config = ConfigReader(provider: provider)
let host = config.string(
    forKey: "database.host",
    default: "localhost"
)
```

#### Poll interval considerations

Choose poll intervals based on how quickly you need to detect changes:

```swift
// Development: Quick feedback
pollInterval: .seconds(1)

// Production: Balanced performance (default)
pollInterval: .seconds(15)

// Batch processing: Resource efficient
pollInterval: .seconds(300)
```

### Watching for changes

The following sections provide examples of watching for changes in configuration from a reloading provider.

#### Individual values

The example below watches for updates in a single key, `database.host`:

```swift
try await config.watchString(
    forKey: "database.host"
) { updates in
    for await host in updates {
        print("Database host updated: \(host)")
    }
}
```

#### Configuration snapshots

The following example reads the `database.host` and `database.password` key with the guarantee that you read them from the same update of the reloading file:

```swift
try await config.watchSnapshot { updates in
    for await snapshot in updates {
        let host = snapshot.string(forKey: "database.host")
        let password = snapshot.string(forKey: "database.password", isSecret: true)
        print("Configuration updated - Database: \(host)")
    }
}
```

### Comparison with static providers

| Feature | Static providers | Reloading providers |
|---------|------------------|---------------------|
| **File reading** | Load once at startup | Reloading on change |
| **Service lifecycle** | Not required | Conforms to `Service` and you must run in a `ServiceGroup` |
| **Configuration updates** | Require restart | Automatic reload |

### Handling missing files during reloading

Reloading providers support the `allowMissing` parameter to handle cases where configuration files might be temporarily missing or optional. This is useful for:

- Optional configuration files that might not exist in all environments.
- Configuration files that the system creates or removes dynamically.
- Graceful handling of file system issues during service startup.

#### Missing file behavior

When `allowMissing` is `false` (the default), missing files cause errors:

```swift
let provider = try await ReloadingFileProvider<JSONSnapshot>(
    filePath: "/etc/config.json",
    allowMissing: false  // Default: throw error if file is missing
)
// Will throw an error if config.json doesn't exist
```

When `allowMissing` is `true`, the provider treats missing files as empty configuration:

```swift
let provider = try await ReloadingFileProvider<JSONSnapshot>(
    filePath: "/etc/config.json",
    allowMissing: true  // Treat missing file as empty config
)
// Won't throw if config.json is missing - uses empty config instead
```

#### Behavior during reloading

If a file becomes missing after the provider starts, the behavior depends on the `allowMissing` setting:

- **`allowMissing: false`**: The provider keeps the last known configuration and logs an error.
- **`allowMissing: true`**: The provider switches to empty configuration.

In both cases, when a valid file comes back, the provider will load it and recover.

```swift
// Example: File gets deleted during runtime
try await config.watchString(forKey: "database.host", default: "localhost") { updates in
    for await host in updates {
        // With allowMissing: true, this will receive "localhost" when file is removed
        // With allowMissing: false, this keeps the last known value
        print("Database host: \(host)")
    }
}
```

> Important: The `allowMissing` parameter only affects missing files. Malformed files will still cause parsing errors regardless of this setting.

### Advanced features

#### Configuration-driven setup

The following example sets up an environment variable provider to select the path
and interval to watch for a JSON file that contains the configuration for your app:

```swift
let envProvider = EnvironmentVariablesProvider()
let envConfig = ConfigReader(provider: envProvider)

let jsonProvider = try await ReloadingFileProvider<JSONSnapshot>(
    config: envConfig.scoped(to: "json")
    // Reads JSON_FILE_PATH and JSON_POLL_INTERVAL_SECONDS
)
```

#### Observability metrics

``ReloadingFileProvider`` emits metrics through [`swift-metrics`](https://github.com/apple/swift-metrics). By default, the provider uses the process-wide `MetricsSystem.factory`, so whichever backend you bootstrap (for example, `StatsdMetrics` or `PrometheusMetrics`) receives its counters and gauges. Pass an explicit `metrics:` argument to the initializer when you want to redirect them — for example, to an isolated registry in tests:

```swift
let provider = try await ReloadingFileProvider<JSONSnapshot>(
    filePath: "/etc/config.json",
    metrics: myTestMetricsFactory
)
```

Every metric label starts with a prefix derived from the provider name, lowercased (for example, `reloadingfileprovider_poll_ticks_total`):

| Metric                         | Type    | Meaning                                                                                                                 |
|--------------------------------|---------|-------------------------------------------------------------------------------------------------------------------------|
| `<prefix>_poll_ticks_total`    | Counter | Increments on every polling-cycle timestamp check, whether or not a reload was needed.                                  |
| `<prefix>_poll_errors_total`   | Counter | Increments when the polling timestamp check fails (file-system error, permission issue, and so on).                     |
| `<prefix>_reloads_total`       | Counter | Increments each time the provider successfully reloads and parses the configuration file after detecting a change.     |
| `<prefix>_reload_errors_total` | Counter | Increments when a reload fails (parse error, file-system error, and so on).                                             |
| `<prefix>_file_size_bytes`     | Gauge   | Current on-disk size of the configuration file in bytes, refreshed after every successful reload.                       |
| `<prefix>_watchers_active`     | Gauge   | Total number of active value and snapshot watchers currently registered with the provider.                              |

### Migration from static providers

1. **Replace initialization**:
   ```swift
   // Before
   let provider = try await FileProvider<JSONSnapshot>(filePath: "/etc/config.json")

   // After
   let provider = try await ReloadingFileProvider<JSONSnapshot>(filePath: "/etc/config.json")
   ```

2. **Add the provider to a ServiceGroup**:
   ```swift
   let serviceGroup = ServiceGroup(services: [provider], logger: logger)
   try await serviceGroup.run()
   ```

3. **Use ConfigReader**:
   ```swift
   let config = ConfigReader(provider: provider)

   // Live updates.
   try await config.watchDouble(forKey: "timeout") { updates in
       // Handle changes
   }

   // On-demand reads - returns the current value, so might change over time.
   let timeout = config.double(forKey: "timeout", default: 60.0)
   ```

For guidance on choosing between get, fetch, and watch access patterns with reloading providers, see <doc:Choosing-access-patterns>. For troubleshooting reloading provider issues, check out <doc:Troubleshooting>. To learn about in-memory providers as an alternative, see <doc:Using-in-memory-providers>. If you need to create your own reloading provider for a custom data source, see <doc:Implementing-a-provider>.

