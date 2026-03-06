# Migrating to Swift Configuration

Evolve from scattered environment variable reads to production-ready configuration.

## Overview

Swift Configuration replaces scattered `ProcessInfo` calls with a structured
reader that provides type safety, fallback hierarchies, and secret handling.
This guide walks through the migration incrementally — starting with a single
value and building up to a fully testable, multi-source configuration.

> Tip: Starting a new project? Skip this guide and go straight to
> <doc:Configuring-applications>.

For a video walkthrough, see
[the ServerSide.swift conference talk](https://www.youtube.com/watch?v=I3lYW6OEyIs).

### Before you begin

Here's a typical starting point — a to-do app with configuration scattered
across environment variables and hard-coded defaults:

```swift
import Foundation

// main.swift
let logLevel = ProcessInfo.processInfo.environment["LOG_LEVEL"] ?? "info"
logger.logLevel = Logger.Level(rawValue: logLevel) ?? .info

let host = ProcessInfo.processInfo.environment["HOST"] ?? "0.0.0.0"
let port = Int(ProcessInfo.processInfo.environment["PORT"] ?? "8080")!

let dbURL = ProcessInfo.processInfo.environment["DATABASE_URL"]!
let apiKey = ProcessInfo.processInfo.environment["API_KEY"]!
let timeout = Double(ProcessInfo.processInfo.environment["TIMEOUT"] ?? "30")!
```

This works, but as the project grows, problems emerge: every value is a
string that you force-cast, the same key gets read in multiple places with
different defaults, testing requires mutating global process state, and a
stray `print` can leak your API key.

### Add the dependency

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/apple/swift-configuration", from: "1.0.0"),
],
targets: [
    .executableTarget(
        name: "TodoApp",
        dependencies: [
            .product(name: "Configuration", package: "swift-configuration"),
        ]
    ),
]
```

### Replace your first read

Start with one value — `port`. Replace the manual parsing with a type-safe
read from a ``ConfigReader``:

**Before:**
```swift
let port = Int(ProcessInfo.processInfo.environment["PORT"] ?? "8080")!
```

**After:**
```swift
import Configuration

let config = ConfigReader(provider: EnvironmentVariablesProvider())
let port = config.int(forKey: "port", default: 8080)
```

- **Type-safe.** `int(forKey:default:)` returns an `Int` — no force-unwrap,
  no crash on invalid input.
- **Key convention.** You write `"port"` and
  ``EnvironmentVariablesProvider`` maps it to `PORT` automatically.

### Consolidate into one place

Now apply the same pattern to every value. Instead of leaving reads scattered
across files, extract them into an `AppConfiguration` struct — a single
source of truth for what the app needs:

```swift
// AppConfiguration.swift
import Configuration

struct AppConfiguration {
    let host: String
    let port: Int
    let databaseURL: String
    let apiKey: String
    let requestTimeout: Double

    init(config: ConfigReader) throws {
        self.host = config.string(forKey: "host", default: "0.0.0.0")
        self.port = config.int(forKey: "port", default: 8080)
        self.databaseURL = try config.requiredString(forKey: "database.url")
        self.apiKey = try config.requiredString(forKey: "api.key")
        self.requestTimeout = config.double(forKey: "api.timeout", default: 30.0)
    }
}
```

```swift
// main.swift
import Configuration

let config = ConfigReader(provider: EnvironmentVariablesProvider())
let appConfig = try AppConfiguration(config: config)

try await startServer(host: appConfig.host, port: appConfig.port)
```

New team members read `AppConfiguration.swift` to understand what the app
needs. Required values like `database.url` throw a clear error at startup —
not a crash deep in a request handler.

### Add a fallback hierarchy

Right now you're reading from environment variables only. In practice, you
want a JSON file for local development, environment variables for production,
and maybe a secret volume in Kubernetes.

Add more providers to the ``ConfigReader`` — the first one that has a value
wins:

```swift
// main.swift
let config = ConfigReader(providers: [
    EnvironmentVariablesProvider(),
    try await FileProvider<JSONSnapshot>(
        filePath: "/etc/todo-app/config.json",
        allowMissing: true
    ),
])

let appConfig = try AppConfiguration(config: config)
```

`AppConfiguration` doesn't change — only the provider list does. The same
struct works in every environment:

**Local development** — a JSON file provides defaults:
```json
{
    "host": "localhost",
    "port": 9090,
    "database": { "url": "postgres://localhost/todos_dev" },
    "api": { "key": "dev-key", "timeout": 5.0 }
}
```

**Production** — environment variables take priority:
```bash
export DATABASE_URL="postgres://prod-host/todos"
export API_KEY="real-production-key"
```

Each key automatically maps to the appropriate convention for each provider:

| Config key | Environment variable | JSON path |
|---|---|---|
| `host` | `HOST` | `host` |
| `port` | `PORT` | `port` |
| `database.url` | `DATABASE_URL` | `database.url` |
| `api.key` | `API_KEY` | `api.key` |
| `api.timeout` | `API_TIMEOUT` | `api.timeout` |

### Protect secrets

Mark sensitive values with `isSecret` so they're never logged accidentally.
Update the line in `AppConfiguration`:

```swift
        self.apiKey = try config.requiredString(forKey: "api.key", isSecret: true)
```

Then add an ``AccessLogger`` to see every configuration read — secret values
appear as `<REDACTED>`:

```swift
// main.swift
import Logging

let logger = Logger(label: "todo-app")

let config = ConfigReader(
    providers: [
        EnvironmentVariablesProvider(),
        try await FileProvider<JSONSnapshot>(
            filePath: "/etc/todo-app/config.json",
            allowMissing: true
        ),
    ],
    accessReporter: AccessLogger(logger: logger)
)
```

> Note: ``AccessLogger`` requires the `Logging` package trait. Add it to your
> dependency: `.package(url: "...", from: "1.0.0", traits: [.defaults, "Logging"])`.

For complete guidance, see <doc:Handling-secrets-correctly>.

### Make it testable

The `AppConfiguration` struct is already testable — pass an
``InMemoryProvider`` instead of real environment variables:

```swift
import Testing
import Configuration

@Test func defaultPort() throws {
    let config = ConfigReader(provider: InMemoryProvider(values: [
        "database.url": "postgres://test/todos_test",
        "api.key": "test-key",
    ]))
    let appConfig = try AppConfiguration(config: config)
    #expect(appConfig.port == 8080)
}

@Test func overriddenPort() throws {
    let config = ConfigReader(provider: InMemoryProvider(values: [
        "port": 9090,
        "database.url": "postgres://test/todos_test",
        "api.key": "test-key",
    ]))
    let appConfig = try AppConfiguration(config: config)
    #expect(appConfig.port == 9090)
}
```

Each test is completely isolated — no environment variable pollution or test
ordering dependencies.

### Use scoped readers for libraries

The to-do app configures an HTTP client with `api.timeout` — but that
configuration really belongs to the HTTP client library. The real power of
Swift Configuration comes when libraries accept a ``ConfigReader`` directly.

The pattern: identify an existing type in your library that represents
configuration, and add a method that takes a ``ConfigReader``:

```swift
// In a library
public struct HTTPClientConfiguration {
    public let timeout: Double
    public let maxConnections: Int

    public init(config: ConfigReader) {
        self.timeout = config.double(forKey: "timeout", default: 30.0)
        self.maxConnections = config.int(forKey: "maxConnections", default: 5)
    }
}
```

The calling application uses ``ConfigReader/scoped(to:)`` to avoid key
collisions — `timeout` reads from `http.client.timeout`, which maps to
`HTTP_CLIENT_TIMEOUT` as an environment variable:

```swift
let httpConfig = HTTPClientConfiguration(
    config: config.scoped(to: "http.client")
)
```

As a library author, this puts you in control over the keys, types, and
defaults for your library's configuration. As the library adds more options,
adopters benefit immediately without code changes.

For a complete guide, see <doc:Configuring-libraries>.

### Summary

| Concern | Before | After |
|---|---|---|
| Where config is read | Scattered across files | One `AppConfiguration` struct |
| Type safety | Force-cast from strings | Typed readers with defaults |
| Required values | Crash at runtime | Clear error at startup |
| Secrets | Visible in logs | Auto-redacted with `isSecret` |
| Config sources | Environment variables only | Hierarchical: env vars → file → defaults |
| Testing | Mutate `ProcessInfo` | ``InMemoryProvider`` per test |
| Libraries | Accept raw strings | Accept ``ConfigReader``, scope as needed |

Each step is incremental — apply them one at a time to an existing codebase.

For more configuration guidance, see:

@Links(visualStyle: list) {
    - <doc:Configuring-applications>
    - <doc:Configuring-libraries>
    - <doc:Best-practices>
    - <doc:Choosing-access-patterns>
    - <doc:Choosing-reader-methods>
    - <doc:Using-reloading-providers>
    - <doc:Handling-secrets-correctly>
    - <doc:Troubleshooting>
}
