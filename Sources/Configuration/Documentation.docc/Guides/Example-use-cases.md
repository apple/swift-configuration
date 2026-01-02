# Example use cases

Review common use cases with ready-to-copy code samples.

## Overview

For complete working examples with step-by-step instructions, see the [Examples directory](https://github.com/apple/swift-configuration/tree/main/Examples) in the repository.

### Reading from environment variables

Use ``EnvironmentVariablesProvider`` to read configuration values from environment variables where your app launches. 
The following example creates a ``ConfigReader`` with an environment variable provider, and reads the key `server.port`,
providing a default value of `8080`:

```swift
import Configuration

let config = ConfigReader(provider: EnvironmentVariablesProvider())
let port = config.int(forKey: "server.port", default: 8080)
```

The default environment key encoder uses an underscore to separate key components, making the environment
variable name above `SERVER_PORT`.

### Reading from a JSON configuration file

You can store multiple configuration values together in a JSON file and read them from the filesystem using ``FileProvider`` with ``JSONSnapshot``.
The following example creates a ``ConfigReader`` for a JSON file at the path `/etc/config.json`, and reads a url and port
number collected as properties of the `database` JSON object:

```swift
import Configuration

let config = ConfigReader(
    provider: try await FileProvider<JSONSnapshot>(filePath: "/etc/config.json")
)

// Access nested values using dot notation.
let databaseURL = config.string(forKey: "database.url", default: "localhost")
let databasePort = config.int(forKey: "database.port", default: 5432)
```

The matching JSON for this configuration might look like:

```json
{
    "database": {
        "url": "localhost",
        "port": 5432
    }
}
```

### Reading from a directory of secret files

Use the ``DirectoryFilesProvider`` to read multiple values collected together in a directory on the filesystem, each
in a separate file. The default directory key encoder uses a hyphen in the filename to separate key components.
The following example uses the directory `/run/secrets` as a base, and reads the file `database-password` as 
the key `database.password`:

```swift
import Configuration

// Common pattern for secrets downloaded by an init container.
let config = ConfigReader(
    provider: try await DirectoryFilesProvider(
        directoryPath: "/run/secrets"
    )
)

// Reads the file `/run/secrets/database-password`
let dbPassword = config.string(forKey: "database.password")
```

This pattern is useful for reading secrets that your infrastructure makes available on the file system, 
such as Kubernetes secrets mounted into a container's filesystem.

> Tip: For comprehensive guidance on handling secrets securely, see <doc:Handling-secrets-correctly>.

### Handling optional configuration files

File-based providers support an `allowMissing` parameter to control whether the provider throws an error for missing files or treats them as empty configuration. This is useful when configuration files are optional.

When `allowMissing` is `false` (the default), missing files throw an error:

```swift
import Configuration

// This will throw an error if config.json doesn't exist
let config = ConfigReader(
    provider: try await FileProvider<JSONSnapshot>(
        filePath: "/etc/config.json",
        allowMissing: false  // This is the default
    )
)
```

When `allowMissing` is `true`, the provider treats missing files as empty configuration:

```swift
import Configuration

// This won't throw if config.json is missing - treats it as empty
let config = ConfigReader(
    provider: try await FileProvider<JSONSnapshot>(
        filePath: "/etc/config.json",
        allowMissing: true
    )
)

// Returns the default value if the file is missing
let port = config.int(forKey: "server.port", default: 8080)
```

The same applies to other file-based providers:

```swift
// Optional secrets directory
let secretsConfig = ConfigReader(
    provider: try await DirectoryFilesProvider(
        directoryPath: "/run/secrets",
        allowMissing: true
    )
)

// Optional environment file
let envConfig = ConfigReader(
    provider: try await EnvironmentVariablesProvider(
        environmentFilePath: "/etc/app.env",
        allowMissing: true
    )
)

// Optional reloading configuration
let reloadingConfig = ConfigReader(
    provider: try await ReloadingFileProvider<YAMLSnapshot>(
        filePath: "/etc/dynamic-config.yaml",
        allowMissing: true
    )
)
```

> Important: The `allowMissing` parameter only affects missing files. Malformed files, such as invalid JSON and YAML syntax errors will still throw parsing errors regardless of this setting.

### Setting up a fallback hierarchy

Use multiple providers together to provide a configuration hierarchy that can override values at different levels.
The following example uses both an environment variable provider and a JSON provider together, with values from 
environment variables overriding values from the JSON file.
In this example, the defaults are provided using an ``InMemoryProvider``, which are only read if the environment 
variable or the JSON key don't exist:

```swift
import Configuration

let config = ConfigReader(providers: [
    // First check environment variables.
    EnvironmentVariablesProvider(),
    // Then check the config file.
    try await FileProvider<JSONSnapshot>(filePath: "/etc/config.json"),
    // Finally, use hardcoded defaults.
    InMemoryProvider(values: [
        "app.name": "MyApp",
        "server.port": 8080,
        "logging.level": "info"
    ])
])
```

### Fetching a value from a remote source

You can host dynamic configuration that your app can retrieve remotely and use either the "fetch" or "watch" access pattern.
The following example uses the "fetch" access pattern to asynchronously retrieve a configuration from the remote provider:

```swift
import Configuration

let myRemoteProvider = MyRemoteProvider(...)
let config = ConfigReader(provider: myRemoteProvider)

// Makes a network call to retrieve the up-to-date value.
let samplingRatio = try await config.fetchDouble(forKey: "sampling.ratio")
```

> Tip: To understand when to use each access pattern, check out <doc:Choosing-access-patterns>.

### Watching for configuration changes

You can periodically update configuration values using a reloading provider.
The following example reloads a YAML file from the filesystem every 30 seconds, and illustrates 
using ``ConfigReader/watchInt(forKey:isSecret:fileID:line:updatesHandler:)`` to provide an async sequence 
of updates that you can apply.

```swift
import Configuration
import ServiceLifecycle

// Create a reloading YAML provider
let provider = try await ReloadingFileProvider<YAMLSnapshot>(
    filePath: "/etc/app-config.yaml",
    pollInterval: .seconds(30)
)
// Omitted: add `provider` to the ServiceGroup.

let config = ConfigReader(provider: provider)

// Watch for timeout changes and update HTTP client configuration.
// Needs to run in a separate task from the provider.
try await config.watchInt(forKey: "http.requestTimeout", default: 30) { updates in
    for await timeout in updates {
        print("HTTP request timeout updated: \(timeout)s")
        // Update HTTP client timeout configuration in real-time
    }
}
```

> Important: When you use a reloading provider, integrate it into the service lifecycle of your app to ensure
that it runs and is cancelled correctly on app termination.

For details on reloading providers and ServiceLifecycle integration, see <doc:Using-reloading-providers>.

### Prefixing configuration keys

In most cases, the provider can directly use the configuration key from the reader, for
example using `http.timeout` as the environment variable name `HTTP_TIMEOUT`.

Sometimes you might need to transform the incoming keys in some way before the provider receives them.
A common example is prefixing each key with a constant prefix, for example `myapp`, turning the key `http.timeout`
to `myapp.http.timeout`.

You can use ``KeyMappingProvider`` and related extensions on ``ConfigProvider`` to achieve that.

The following example uses the key mapping provider to adjust an environment variable provider to look for keys with the prefix `myapp`:

```swift
import Configuration

// Create a base provider for environment variables
let envProvider = EnvironmentVariablesProvider()

// Wrap it with a key mapping provider to automatically prepend "myapp." to all keys
let prefixedProvider = envProvider.prefixKeys(with: "myapp")

let config = ConfigReader(provider: prefixedProvider)

// This reads from the "MYAPP_DATABASE_URL" environment variable.
let databaseURL = config.string(forKey: "database.url", default: "localhost")
```

For more configuration guidance, see <doc:Best-practices>.
To understand different reader method variants, check out <doc:Choosing-reader-methods>.
