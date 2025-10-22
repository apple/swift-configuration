# ``Configuration``

A Swift library for reading configuration in applications and libraries.

## Overview

Swift Configuration defines an abstraction between configuration _readers_ and _providers_.

Applications and libraries _read_ configuration through a consistent API, while the actual _provider_ is set up once at the application's entry point.

For example, to read the timeout configuration value for an HTTP client, check out the following examples using different providers:

@TabNavigator {
    @Tab("Environment variables") {
        ```env
        # Environment variables:
        HTTP_TIMEOUT=30
        ```
        ```swift
        let provider = EnvironmentVariablesProvider()
        let config = ConfigReader(provider: provider)
        let httpTimeout = config.int(forKey: "http.timeout", default: 60)
        print(httpTimeout) // prints 30
        ```
    }
    @Tab("Command line arguments") {
        ```bash
        # Program invoked with:
        program --http-timeout 30
        ```
        ```swift
        let provider = CommandLineArgumentsProvider()
        let config = ConfigReader(provider: provider)
        let httpTimeout = config.int(forKey: "http.timeout", default: 60)
        print(httpTimeout) // prints 30
        ```
    }
    @Tab("JSON") {
        ```json
        {
          "http": {
            "timeout": 30
          }
        }
        ```
        ```swift
        let provider = try await FileProvider<JSONSnapshot>(
            filePath: "/etc/config.json"
        )
        let config = ConfigReader(provider: provider)
        let httpTimeout = config.int(forKey: "http.timeout", default: 60)
        print(httpTimeout) // prints 30
        ```
    }
    @Tab("Reloading JSON") {
        ```json
        {
          "http": {
            "timeout": 30
          }
        }
        ```
        ```swift
        let provider = try await ReloadingFileProvider<JSONSnapshot>(
            filePath: "/etc/config.json"
        )
        // Omitted: Add `provider` to a ServiceGroup
        let config = ConfigReader(provider: provider)
        let httpTimeout = config.int(forKey: "http.timeout", default: 60)
        print(httpTimeout) // prints 30
        ```
    }
    @Tab("YAML") {
        ```yaml
        http:
          timeout: 30
        ```
        ```swift
        let provider = try await FileProvider<YAMLSnapshot>(
            filePath: "/etc/config.yaml"
        )
        let config = ConfigReader(provider: provider)
        let httpTimeout = config.int(forKey: "http.timeout", default: 60)
        print(httpTimeout) // prints 30
        ```
    }
    @Tab("Reloading YAML") {
        ```yaml
        http:
          timeout: 30
        ```
        ```swift
        let provider = try await ReloadingFileProvider<YAMLSnapshot>(
            filePath: "/etc/config.yaml"
        )
        // Omitted: Add `provider` to a ServiceGroup
        let config = ConfigReader(provider: provider)
        let httpTimeout = config.int(forKey: "http.timeout", default: 60)
        print(httpTimeout) // prints 30
        ```
    }
    @Tab("Directory files") {
        ```
        /
        |-- run
            |-- secrets
                |-- http-timeout
        ```
        Contents of the file `/run/secrets/http-timeout`: `30`.
        ```swift
        let provider = try await DirectoryFilesProvider(
            directoryPath: "/run/secrets"
        )
        let config = ConfigReader(provider: provider)
        let httpTimeout = config.int(forKey: "http.timeout", default: 60)
        print(httpTimeout) // prints 30
        ```
    }
    @Tab("Provider hierarchy") {
        ```swift
        // Environment variables consulted first, then JSON.
        let primaryProvider = EnvironmentVariablesProvider()
        let secondaryProvider = try await JSONProvider(
            filePath: "/etc/config.json"
        )
        let config = ConfigReader(providers: [
            primaryProvider,
            secondaryProvider
        ])
        let httpTimeout = config.int(forKey: "http.timeout", default: 60)
        print(httpTimeout) // prints 30
        ```
    }
    @Tab("In-memory") {
        ```swift
        let provider = InMemoryProvider(values: [
            "http.timeout": 30,
        ])
        let config = ConfigReader(provider: provider)
        let httpTimeout = config.int(forKey: "http.timeout", default: 60)
        print(httpTimeout) // prints 30
        ```
    }
}

For a selection of more detailed examples, read through <doc:Example-use-cases>.

These providers can be combined to form a hierarchy, for details check out <doc:Provider-hierarchy>.

### Quick start

> Important: While this library's API is still in development, use the `.upToNextMinor(from: "...")` dependency constraint to avoid unexpected build breakages. Before we reach 1.0, API-breaking changes may occur between minor `0.x` versions.

Add the dependency to your `Package.swift`:

```swift
.package(url: "https://github.com/apple/swift-configuration", .upToNextMinor(from: "0.2.0"))
```

Add the library dependency to your target:

```swift
.product(name: "Configuration", package: "swift-configuration")
```

Import and use in your code:

```swift
import Configuration

let config = ConfigReader(provider: EnvironmentVariablesProvider())
let httpTimeout = config.int(forKey: "http.timeout", default: 60)
print("The HTTP timeout is: \(httpTimeout)")
```

### Package traits

This package offers additional integrations you can enable using [package traits](https://docs.swift.org/swiftpm/documentation/packagemanagerdocs/addingdependencies#Packages-with-Traits).
To enable an additional trait on the package, update the package dependency:

```diff
.package(
    url: "https://github.com/apple/swift-configuration",
    exact: "...",
+   traits: [.defaults, "OtherFeatureSupport"]
)
```

Available traits:
- **`JSONSupport`** (default): Adds support for ``JSONSnapshot``, which enables using ``FileProvider`` and ``ReloadingFileProvider`` with JSON files.
- **`LoggingSupport`** (opt-in): Adds support for ``AccessLogger``, a way to emit access events into a `SwiftLog.Logger`.
- **`ReloadingSupport`** (opt-in): Adds support for ``ReloadingFileProvider``, which provides auto-reloading capability for file-based configuration.
- **`CommandLineArgumentsSupport`** (opt-in): Adds support for ``CommandLineArgumentsProvider`` for parsing command line arguments.
- **`YAMLSupport`** (opt-in): Adds support for ``YAMLSnapshot``, which enables using ``FileProvider`` and ``ReloadingFileProvider`` with YAML files.

### Supported platforms and minimum versions

The library is supported on macOS, Linux, and Windows.

| Component     | macOS  | Linux, Windows | iOS    | tvOS   | watchOS | visionOS |
| ------------- | -----  | -------------- | ---    | ----   | ------- | -------- |
| Configuration | ✅ 15+ | ✅              | ✅ 18+ | ✅ 18+ | ✅ 11+   | ✅ 2+    |

### Key features

#### Three access patterns

The library provides three distinct ways to read configuration values:

- **Get**: Synchronously return the current value available locally, in memory:
  ```swift
  let timeout = config.int(forKey: "http.timeout", default: 60)
  ```
- **Fetch**: Asynchronously get the most up-to-date value from disk or a remote server:
  ```swift
  let timeout = try await config.fetchInt(forKey: "http.timeout", default: 60)
  ```
- **Watch**: Receive updates when a configuration value changes:
  ```swift
  try await config.watchInt(forKey: "http.timeout", default: 60) { updates in
      for try await timeout in updates {
          print("HTTP timeout updated to: \(timeout)")
      }
  }
  ```

For detailed guidance on when to use each access pattern, see <doc:Choosing-access-patterns>.
Within each of the access patterns, the library offers different reader methods that reflect your needs of 
optional, default, and required configuration parameters.
To understand the choices available, see <doc:Choosing-reader-methods>.

#### Providers

The library includes comprehensive built-in provider support:

- Environment variables: ``EnvironmentVariablesProvider``
- Command-line arguments: ``CommandLineArgumentsProvider``
- JSON file: ``FileProvider`` and ``ReloadingFileProvider`` with ``JSONSnapshot``
- YAML file: ``FileProvider`` and ``ReloadingFileProvider`` with ``YAMLSnapshot``
- Directory of files: ``DirectoryFilesProvider``
- In-memory: ``InMemoryProvider`` and ``MutableInMemoryProvider``
- Key transforming: ``KeyMappingProvider``

You can also implement a custom ``ConfigProvider``.

#### Provider hierarchy

In addition to using providers individually, you can create fallback behavior using an array of providers.
The first provider that returns a non-nil value wins.

The following example illustrates a hierarchy of provides, with environmental variables overrides winning 
over command line arguments, a file at `/etc/config.json`, and in-memory defaults:

```swift
// Create a hierarchy of providers with fallback behavior.
let config = ConfigReader(providers: [
    // First, check environment variables.
    EnvironmentVariablesProvider(),
    // Then, check command-line options.
    CommandLineArgumentsProvider(),
    // Then, check a JSON config file.
    try await FileProvider<JSONSnapshot>(filePath: "/etc/config.json"),
    // Finally, fall back to in-memory defaults.
    InMemoryProvider(values: [
        "http.timeout": 60,
    ])
])

// Uses the first provider that has a value for "http.timeout".
let timeout = config.int(forKey: "http.timeout", default: 15)
```

#### Hot reloading

Long-running services can periodically reload configuration with ``ReloadingFileProvider``:

```swift
let provider = try await ReloadingFileProvider<JSONSnapshot>(filePath: "/etc/config.json")
// Omitted: add provider to a ServiceGroup
let config = ConfigReader(provider: provider)

try await config.watchInt(forKey: "http.timeout", default: 60) { updates in
    for try await timeout in updates {
        print("HTTP timeout updated to: \(timeout)")
    }
}
```

Read <doc:Using-reloading-providers> for details on how to receive updates as configuration changes.

#### Namespacing and scoped readers

The built-in namespacing of ``ConfigKey`` interprets `"http.timeout"` as an array of two components: `"http"` and `"timeout"`.
The following example uses ``ConfigReader/scoped(to:context:keyDecoderOverride:)`` to create a namespaced reader with the key `"http"`, to allow reads to use the shorter key `"timeout"`:

Consider the following JSON configuration:

```json
{
  "http": {
    "timeout": 60
  }
}
```

```swift
// Create the root reader.
let config = ConfigReader(provider: provider)

// Create a scoped reader for HTTP settings.
let httpConfig = config.scoped(to: "http")

// Now you can access values with shorter keys.
// Equivalent to reading "http.timeout" on the root reader.
let timeout = httpConfig.int(forKey: "timeout")
```

#### Debugging and troubleshooting

Debugging with ``AccessReporter`` makes it possible to log all accesses to a config reader:

```swift
let logger = Logger(label: "config")
let config = ConfigReader(
    provider: provider,
    accessReporter: AccessLogger(logger: logger)
)
// Now all configuration access is logged, with secret values redacted
```

You can also add the following environment variable, and emit log accesses into a file without any code changes:

```env
CONFIG_ACCESS_LOG_FILE=/var/log/myapp/config-access.log
```

and then read the file:

```zsh
tail -f /var/log/myapp/config-access.log
```

Check out the built-in ``AccessLogger``, ``FileAccessLogger``, and <doc:Troubleshooting>.

#### Secrets handling

The library provides built-in support for handling sensitive configuration values securely:

```swift
// Mark sensitive values as secrets to prevent them from appearing in logs
let privateKey = try snapshot.requiredString(forKey: "mtls.privateKey", isSecret: true)
let optionalAPIToken = config.string(forKey: "api.token", isSecret: true)
```

When values are marked as secrets, they are automatically redacted from access logs and debugging output. 
Read <doc:Handling-secrets-correctly> for guidance on best practices for secrets management.

#### Consistent snapshots

Retrieve related values from a consistent snapshot using ``ConfigSnapshotReader``, which you
get from calling ``ConfigReader/withSnapshot(_:)``.

This ensures that multiple values are read from a single snapshot inside each provider, even when using
providers that update their internal values.
For example by downloading new data periodically:

```swift
let config = /* a reader with one or more providers that change values over time */
try config.withSnapshot { snapshot in
    let certificate = try snapshot.requiredString(forKey: "mtls.certificate")
    let privateKey = try snapshot.requiredString(forKey: "mtls.privateKey", isSecret: true)
    // `certificate` and `privateKey` are guaranteed to come from the same snapshot in the provider
}
```

#### Custom key syntax

Customizable shorthand key syntax using ``ConfigKeyDecoder`` allows namespacing using not just the default dot-separated `http.timeout`, but any custom convention, such as `http::timeout`:

```swift
// Create a custom key decoder that uses double-colon separator
let doubleColonDecoder = SeparatorKeyDecoder(separator: "::")

// Use the keyDecoder parameter when creating the config reader
let config = ConfigReader(
    provider: EnvironmentVariablesProvider(),
    keyDecoder: doubleColonDecoder
)

// Now you can use double-colon syntax in your keys
let timeout = config.int(forKey: "http::timeout", default: 60)
```

#### Extensible ecosystem

Any package can implement a ``ConfigProvider``, making the ecosystem extensible for custom configuration sources.

## Topics

### Essentials
- <doc:Configuring-applications>
- <doc:Configuring-libraries>
- <doc:Example-use-cases>
- <doc:Best-practices>

### Readers and providers
- ``ConfigReader``
- ``ConfigProvider``
- ``ConfigSnapshotReader``
- <doc:Choosing-access-patterns>
- <doc:Choosing-reader-methods>
- <doc:Handling-secrets-correctly>

### Built-in providers
- ``EnvironmentVariablesProvider``
- ``CommandLineArgumentsProvider``
- ``FileProvider``
- ``ReloadingFileProvider``
- ``JSONSnapshot``
- ``YAMLSnapshot``
- <doc:Using-reloading-providers>
- ``DirectoryFilesProvider``
- <doc:Using-in-memory-providers>
- ``InMemoryProvider``
- ``MutableInMemoryProvider``
- ``KeyMappingProvider``

### Creating a custom provider
- ``ConfigSnapshotProtocol``
- ``FileParsingOptionsProtocol``
- ``ConfigProvider``
- ``ConfigContent``
- ``ConfigValue``
- ``ConfigType``
- ``LookupResult``
- ``SecretsSpecifier``
- ``ConfigUpdatesAsyncSequence``

### Configuration keys
- ``ConfigKey``
- ``AbsoluteConfigKey``
- ``ConfigContextValue``
- ``ConfigKeyEncoder``
- ``ConfigKeyDecoder``
- ``SeparatorKeyEncoder``
- ``SeparatorKeyDecoder``
- ``DirectoryFileKeyEncoder``

### Troubleshooting and access reporting
- <doc:Troubleshooting>
- ``AccessReporter``
- ``AccessLogger``
- ``FileAccessLogger``
- ``AccessEvent``
- ``BroadcastingAccessReporter``

### Value conversion
- ``ExpressibleByConfigString``
- ``ConfigBytesFromStringDecoder``
- ``ConfigBytesFromBase64StringDecoder``
- ``ConfigBytesFromHexStringDecoder``

### Contributing
- <doc:Development>
- <doc:Proposals>
