# Swift Configuration

[![](https://img.shields.io/badge/docc-read_documentation-blue)](https://swiftpackageindex.com/apple/swift-configuration/documentation)
[![](https://img.shields.io/github/v/release/apple/swift-configuration)](https://github.com/apple/swift-configuration/releases)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fapple%2Fswift-configuration%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/apple/swift-configuration)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fapple%2Fswift-configuration%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/apple/swift-configuration)

A Swift library for reading configuration in applications and libraries.

- 📚 **Documentation** is available on the [Swift Package Index](https://swiftpackageindex.com/apple/swift-configuration/documentation/configuration).
- 💻 **Examples** are available [just below](#Examples), in the [Examples](Examples/) directory, and on the [Example use cases](https://swiftpackageindex.com/apple/swift-configuration/documentation/configuration/example-use-cases) page.
- 🚀 **Contributions** are welcome, please see [CONTRIBUTING.md](CONTRIBUTING.md).
- 🪪 **License** is Apache 2.0, repeated in [LICENSE](LICENSE.txt).
- 🔒 **Security** issues should be reported via the process in [SECURITY.md](SECURITY.md).

## Overview

Swift Configuration defines an abstraction layer between configuration [readers](https://swiftpackageindex.com/apple/swift-configuration/documentation/configuration/configreader) and [providers](https://swiftpackageindex.com/apple/swift-configuration/documentation/configuration/configprovider).

Applications and libraries _read_ configuration through a consistent API, while the actual _provider_ is set up once at the application's entry point.

## Examples

Swift Configuration allows you to combine multiple providers in a hierarchy, where values from higher-priority sources override those from lower-priority ones.

For example, if you have a default configuration in JSON:
```json
{
  "http": {
    "timeout": 30
  }
}
```
And want to be able to provide an override for that using an environment variable:

```env
# Environment variables:
HTTP_TIMEOUT=15
```

The example code below creates the two relevant providers, and resolves them in the order you list:

```swift
let config = ConfigReader(providers: [
    EnvironmentVariablesProvider(),
    try await JSONProvider(filePath: "/etc/config.json")
])
let httpTimeout = config.int(forKey: "http.timeout", default: 60)
print(httpTimeout) // prints 15
```

The resolved configuration value is `15` from the environment variable. Without the environment variable, it would use `30` from the JSON file.
If both sources are unavailable, the fallback default of `60` is returned.

> Tip: More example use cases are described in [example use cases](https://swiftpackageindex.com/apple/swift-configuration/documentation/configuration/example-use-cases), and complete working examples are available in the [Examples](Examples/) directory.

## Quick start

> Important: While this library's API is still in development, use the `.upToNextMinor(from: "...")` dependency constraint to avoid unexpected build breakages. Before we reach 1.0, API-breaking changes may occur between minor `0.x` versions.

Add the dependency to your `Package.swift`:

```swift
.package(url: "https://github.com/apple/swift-configuration", .upToNextMinor(from: "0.1.0"))
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

## Getting started guides
- [Configuring applications](https://swiftpackageindex.com/apple/swift-configuration/documentation/configuration/configuring-applications)
- [Configuring libraries](https://swiftpackageindex.com/apple/swift-configuration/documentation/configuration/configuring-libraries)

For more, check out the full [documentation](https://swiftpackageindex.com/apple/swift-configuration/documentation/configuration).

## Package traits

This package offers additional integrations you can enable using [package traits](https://docs.swift.org/swiftpm/documentation/packagemanagerdocs/addingdependencies#Packages-with-Traits).
To enable an additional trait on the package, update the package dependency:

```diff
.package(
    url: "https://github.com/apple/swift-configuration",
    .upToNextMinor(from: "0.1.0"),
+   traits: [.defaults, "OtherFeatureSupport"]
)
```

Available traits:
- **`JSONSupport`** (default): Adds support for `JSONProvider`, a `ConfigProvider` for reading JSON files.
- **`LoggingSupport`** (opt-in): Adds support for `AccessLogger`, a way to emit access events into a `SwiftLog.Logger`.
- **`ReloadingSupport`** (opt-in): Adds support for auto-reloading variants of file providers, such as `ReloadingJSONProvider` (when `JSONSupport` is enabled) and `ReloadingYAMLProvider` (when `YAMLSupport` is enabled).
- **`CommandLineArgumentsSupport`** (opt-in): Adds support for `CommandLineArgumentsProvider` for parsing command line arguments.
- **`YAMLSupport`** (opt-in): Adds support for `YAMLProvider`, a `ConfigProvider` for reading YAML files.

## Supported platforms and minimum versions

The library is supported on macOS, Linux, and Windows.

| Component     | macOS  | Linux, Windows | iOS    | tvOS   | watchOS | visionOS |
| ------------- | -----  | -------------- | ---    | ----   | ------- | -------- |
| Configuration | ✅ 15+ | ✅              | ✅ 18+ | ✅ 18+ | ✅ 11+   | ✅ 2+    |

## Configuration providers

The library includes comprehensive built-in provider support:

- Environment variables: [`EnvironmentVariablesProvider`](https://swiftpackageindex.com/apple/swift-configuration/documentation/configuration/environmentvariablesprovider)
- Command-line arguments: [`CommandLineArgumentsProvider`](https://swiftpackageindex.com/apple/swift-configuration/documentation/configuration/commandlineargumentsprovider)
- JSON file: [`JSONProvider`](https://swiftpackageindex.com/apple/swift-configuration/documentation/configuration/jsonprovider) and [`ReloadingJSONProvider`](https://swiftpackageindex.com/apple/swift-configuration/documentation/configuration/reloadingjsonprovider)
- YAML file: [`YAMLProvider`](https://swiftpackageindex.com/apple/swift-configuration/documentation/configuration/yamlprovider) and [`ReloadingYAMLProvider`](https://swiftpackageindex.com/apple/swift-configuration/documentation/configuration/reloadingyamlprovider)
- Directory of files: [`DirectoryFilesProvider`](https://swiftpackageindex.com/apple/swift-configuration/documentation/configuration/directoryfilesprovider)
- In-memory: [`InMemoryProvider`](https://swiftpackageindex.com/apple/swift-configuration/documentation/configuration/inmemoryprovider) and [`MutableInMemoryProvider`](https://swiftpackageindex.com/apple/swift-configuration/documentation/configuration/mutableinmemoryprovider)
- Key transforming: [`KeyMappingProvider`](https://swiftpackageindex.com/apple/swift-configuration/documentation/configuration/keymappingprovider)

You can also implement a custom [`ConfigProvider`](https://swiftpackageindex.com/apple/swift-configuration/documentation/configuration/configprovider) for specialized configuration formats and sources.

## Key features
- [3 access patterns: synchronous, asynchronous, and watching](https://swiftpackageindex.com/apple/swift-configuration/documentation/configuration#Three-access-patterns)
- [Provider hierarchy](https://swiftpackageindex.com/apple/swift-configuration/documentation/configuration#Provider-hierarchy)
- [Hot reloading/watching value updates](https://swiftpackageindex.com/apple/swift-configuration/documentation/configuration#Hot-reloading)
- [Namespacing and scoped readers](https://swiftpackageindex.com/apple/swift-configuration/documentation/configuration#Namespacing-and-scoped-readers)
- [Debugging and troubleshooting](https://swiftpackageindex.com/apple/swift-configuration/documentation/configuration#Debugging-and-troubleshooting)
- [Redaction of secrets](https://swiftpackageindex.com/apple/swift-configuration/documentation/configuration/handling-secrets-correctly)
- [Consistent snapshots](https://swiftpackageindex.com/apple/swift-configuration/documentation/configuration#Consistent-snapshots)
- [Custom key syntax](https://swiftpackageindex.com/apple/swift-configuration/documentation/configuration#Custom-key-syntax)

## Documentation

Comprehensive documentation is hosted on the [Swift Package Index](https://swiftpackageindex.com/apple/swift-configuration/documentation/configuration).
