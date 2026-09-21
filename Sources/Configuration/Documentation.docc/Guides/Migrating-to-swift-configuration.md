# Migrating to Swift Configuration

Evolve from scattered environment variable reads to layered configuration.

## Overview

Swift Configuration replaces `ProcessInfo` calls with a structured reader
that provides typed reads, fallback hierarchies, and secret handling.
This guide walks through the migration incrementally, starting with a single
value and building up to a testable, multi-source configuration.

> Tip: Starting a new project? Skip this guide and go straight to
> <doc:Configuring-applications>.

For a video walkthrough, see
[the ServerSide.swift conference talk](https://www.youtube.com/watch?v=I3lYW6OEyIs).

### Before you begin

Here's a typical starting point, a to-do app with configuration in environment
variables and hard-coded defaults:

```swift
// main.swift
import Foundation

let logLevel = ProcessInfo.processInfo.environment["LOG_LEVEL"] ?? "info"
logger.logLevel = Logger.Level(rawValue: logLevel) ?? .info

let host = ProcessInfo.processInfo.environment["HOST"] ?? "0.0.0.0"
let port = Int(ProcessInfo.processInfo.environment["PORT"] ?? "8080")!

let dbURL = ProcessInfo.processInfo.environment["DATABASE_URL"]!
let apiKey = ProcessInfo.processInfo.environment["API_KEY"]!
let timeout = Double(ProcessInfo.processInfo.environment["TIMEOUT"] ?? "30")!
```

This works, but as the project grows, problems emerge: every value is a
string that you force-unwrap, the same key gets read in multiple places with
different defaults, testing requires mutating global process state, and
nothing marks `API_KEY` as sensitive.

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

Start with one value, `port`. Replace the manual parsing with a read from a
``ConfigReader``:

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

`int(forKey:default:)` returns an `Int`, so there's no force-unwrap. You write
`"port"` and ``EnvironmentVariablesProvider`` maps it to `PORT` automatically.

`Int(...)!` traps when `PORT` holds something that isn't a number, while the
`default:` variants return the default instead. A typo in a deployed variable's
value now starts the app on port 8080 rather than failing at launch. Where you'd
rather fail, use the required variants described in
<doc:Choosing-reader-methods>.

### Consolidate into one place

Now apply the same pattern to every value. Instead of leaving reads scattered
across files, extract them into an `AppConfiguration` struct, a single source
of truth for what the app needs:

```swift
// AppConfiguration.swift
import Configuration

struct AppConfiguration {
    let logLevel: String
    let host: String
    let port: Int
    let databaseURL: String
    let apiKey: String
    let requestTimeout: Double

    init(config: ConfigReader) throws {
        self.logLevel = config.string(forKey: "log.level", default: "info")
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
needs. Required values like `database.url` throw at startup, rather than
trapping deep in a request handler.

### Add a fallback hierarchy

Right now you're reading from environment variables only. In practice, you
want a JSON file for local development, environment variables for production,
and maybe a directory of mounted secret files.

Add more providers to the ``ConfigReader``. The first one that has a value
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

`AppConfiguration` doesn't change, only the provider list does. The same
struct works in every environment:

**Local development** uses a JSON file for defaults:
```json
{
    "host": "localhost",
    "port": 9090,
    "database": { "url": "postgres://localhost/todos_dev" },
    "api": { "key": "dev-key", "timeout": 5.0 }
}
```

**Production** gives environment variables priority:
```bash
export DATABASE_URL="postgres://prod-host/todos"
export API_KEY="real-production-key"
```

Each key automatically maps to the appropriate convention for each provider:

| Config key | Environment variable | JSON path |
|---|---|---|
| `log.level` | `LOG_LEVEL` | `log.level` |
| `host` | `HOST` | `host` |
| `port` | `PORT` | `port` |
| `database.url` | `DATABASE_URL` | `database.url` |
| `api.key` | `API_KEY` | `api.key` |
| `api.timeout` | `API_TIMEOUT` | `api.timeout` |

> Important: Check each key against the variables you already deploy. Five of
> these round-trip unchanged, but `TIMEOUT` becomes `API_TIMEOUT` because the
> key is now `api.timeout`. Anything still exporting the old name silently
> falls through to the file or the default. Either rename the variable as you
> deploy, or keep the existing name by wrapping the provider in a
> ``KeyMappingProvider``.

### Protect secrets

Mark sensitive values with `isSecret` so the library redacts them in access
logs. Both credentials qualify here, including the database URL, which
usually carries a password:

```swift
// AppConfiguration.swift
struct AppConfiguration {
    let logLevel: String
    let host: String
    let port: Int
    let databaseURL: String
    let apiKey: String
    let requestTimeout: Double

    init(config: ConfigReader) throws {
        self.logLevel = config.string(forKey: "log.level", default: "info")
        self.host = config.string(forKey: "host", default: "0.0.0.0")
        self.port = config.int(forKey: "port", default: 8080)
        self.databaseURL = try config.requiredString(forKey: "database.url", isSecret: true)
        self.apiKey = try config.requiredString(forKey: "api.key", isSecret: true)
        self.requestTimeout = config.double(forKey: "api.timeout", default: 30.0)
    }
}
```

Then add an ``AccessLogger`` to see every configuration read, where secret
values appear as `<REDACTED>`. It requires the `Logging` package trait, so
enable that in `Package.swift` first:

```diff
 .package(
     url: "https://github.com/apple/swift-configuration",
     from: "1.0.0",
+    traits: [.defaults, "Logging"]
 )
```

Then pass the reporter when you build the reader:

```swift
// main.swift
import Configuration
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
    accessReporter: AccessLogger(logger: logger, level: .info)
)
```

``AccessLogger`` logs at `.debug` by default, which a stock swift-log
bootstrap filters out, so this passes `.info` to make the output visible.

> Warning: `isSecret` controls what the library prints. It doesn't protect the
> `String` once you hold it, so `print(appConfig.apiKey)` still shows the key.

If your deployment mounts secrets as individual files, read them with
``DirectoryFilesProvider``, added first in the reader above so a mounted file
wins over `API_KEY`. It maps `api.key` to a file named `api-key`. By default it
treats every value it reads as secret, so those values are redacted in access
logs:

```diff
 let config = ConfigReader(
     providers: [
+        try await DirectoryFilesProvider(
+            directoryPath: "/run/secrets",
+            allowMissing: true
+        ),
         EnvironmentVariablesProvider(),
         try await FileProvider<JSONSnapshot>(
             filePath: "/etc/todo-app/config.json",
             allowMissing: true
         ),
     ],
     accessReporter: AccessLogger(logger: logger, level: .info)
 )
```

Keep `isSecret: true` in `AppConfiguration` anyway, since the same keys fall
back to environment variables and the JSON file, which by default don't mark
them as secret.

For more on secrets, check out <doc:Handling-secrets-correctly>.

### Make it testable

The `AppConfiguration` struct is already testable. Pass an
``InMemoryProvider`` instead of real environment variables:

```swift
import Testing
import Configuration

@Test func portFallsBackToDefaultWhenUnset() throws {
    let config = ConfigReader(provider: InMemoryProvider(values: [
        "database.url": "postgres://test/todos_test",
        "api.key": "test-key",
    ]))
    let appConfig = try AppConfiguration(config: config)
    #expect(appConfig.port == 8080)
}

@Test func portReadsFromProviderWhenSet() throws {
    let config = ConfigReader(provider: InMemoryProvider(values: [
        "port": 9090,
        "database.url": "postgres://test/todos_test",
        "api.key": "test-key",
    ]))
    let appConfig = try AppConfiguration(config: config)
    #expect(appConfig.port == 9090)
}
```

Each test is isolated, with no environment variable pollution or test
ordering dependencies. For more on testing against configuration, see
<doc:Using-in-memory-providers>.

### Use scoped readers for libraries

The to-do app configures an HTTP client with `api.timeout`, but that
configuration really belongs to the HTTP client library. When a library
accepts a ``ConfigReader`` directly, you can drop `requestTimeout` from
`AppConfiguration` and let the library read its own configuration.

The pattern: identify an existing type in your library that represents
configuration, and add a method that takes a ``ConfigReader``:

```swift
// In a library
public struct HTTPClientConfiguration {
    public let timeout: Double
    public let maxConcurrentConnections: Int

    public init(config: ConfigReader) {
        self.timeout = config.double(forKey: "timeout", default: 30.0)
        self.maxConcurrentConnections = config.int(forKey: "maxConcurrentConnections", default: 5)
    }
}
```

The calling application uses ``ConfigReader/scoped(to:)`` to avoid key
collisions. `timeout` reads from `http.client.timeout`, which maps to
`HTTP_CLIENT_TIMEOUT` as an environment variable:

```swift
let httpConfig = HTTPClientConfiguration(
    config: config.scoped(to: "http.client")
)
```

The key moves again, from `api.timeout` to `http.client.timeout`, so rename
the deployed variable along with it.

As a library author, this puts you in control of the keys, types, and
defaults for your library's configuration. As the library adds more options,
adopters benefit without changing their own code.

For details, check out <doc:Configuring-libraries>.

### Summary

| Concern | Before | After |
|---|---|---|
| Where config is read | Scattered across files | One `AppConfiguration` struct |
| Type conversion | Force-unwrapped from strings | Typed readers with defaults |
| Required values | Crash at runtime | Thrown error at startup |
| Malformed values | Trap at launch | Fall back to the default |
| Secrets | Printed wherever config is logged | Redacted in access logs |
| Config sources | Environment variables only | Hierarchical: env vars → file → defaults |
| Testing | Mutate the process environment | ``InMemoryProvider`` per test |
| Libraries | Accept raw strings | Accept ``ConfigReader``, scope as needed |

The steps are incremental, so apply them one at a time to an existing
codebase.

For more configuration guidance, see <doc:Best-practices>. To understand
different access patterns, refer to <doc:Choosing-access-patterns>. For
providers that reload at runtime, see <doc:Using-reloading-providers>, and for
debugging configuration access, check out <doc:Troubleshooting>.
