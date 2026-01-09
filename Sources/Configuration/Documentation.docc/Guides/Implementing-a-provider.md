# Implementing a custom provider

Create a custom configuration provider to integrate a new data source.

## Overview

Swift Configuration provides built-in providers for common data sources like environment variables, JSON files, and YAML files. When you need to integrate with other configuration sources – such as custom file formats, remote configuration servers, or custom databases – you implement a custom type that conforms to the ``ConfigProvider`` protocol.

### Choose your provider type

Some data sources are inherently immutable, such as command-line arguments, while others change over time, such as files on disk.

Identify the provider type most similar to your data source and follow the recommendations below.

| Type | Use case | Examples |
|------|----------|----------|
| [**File-based**](#Implement-a-file-based-provider) | Custom file formats | JSON, YAML, TOML, XML, plist files |
| [**Immutable**](#Implement-an-immutable-provider) | Values loaded once, never change | Command-line arguments, in-memory values, test fixtures, immutable files |
| [**Dynamic**](#Implement-a-dynamic-provider) | Values change over time | Remote servers, watched files |

### Understand the provider protocol

The ``ConfigProvider`` protocol defines five methods and one property:

```swift
public protocol ConfigProvider: Sendable {
    /// Human-readable name for logging and diagnostics.
    var providerName: String { get }

    /// Returns the current cached value synchronously.
    func value(forKey key: AbsoluteConfigKey, type: ConfigType) throws -> LookupResult

    /// Fetches a fresh value from the data source asynchronously.
    func fetchValue(forKey key: AbsoluteConfigKey, type: ConfigType) async throws -> LookupResult

    /// Monitors a key for changes over time.
    func watchValue<Return: ~Copyable>(
        forKey key: AbsoluteConfigKey,
        type: ConfigType,
        updatesHandler: (_ updates: ConfigUpdatesAsyncSequence<Result<LookupResult, any Error>, Never>) async throws -> Return
    ) async throws -> Return

    /// Returns an immutable snapshot of the current state.
    func snapshot() -> any ConfigSnapshot

    /// Monitors the provider for state changes.
    func watchSnapshot<Return: ~Copyable>(
        updatesHandler: (_ updates: ConfigUpdatesAsyncSequence<any ConfigSnapshot, Never>) async throws -> Return
    ) async throws -> Return
}
```

The three access patterns serve different needs:

- **Get** (`value(...)`, `snapshot()`): Fast, synchronous access to cached values.
- **Fetch** (`fetchValue(...)`): Asynchronous access that can contact the authoritative source.
- **Watch** (`watchValue(...)`, `watchSnapshot(...)`): Reactive access that can emit updates over time.

> Tip: For more details on access patterns, check out <doc:Choosing-access-patterns>.

### Implement a file-based provider

To support custom file formats like TOML or XML, you don't need to implement a whole provider yourself - the library comes with the following generic file providers that handle any format implementing the ``FileConfigSnapshot`` protocol:

- ``FileProvider``: An immutable file provider, loads the file once at initialization time, then never changes again.
- ``ReloadingFileProvider``: A mutable file provider that loads the file once at initialization time, and then periodically checks the file for changes, reloading it again as necessary. Since it runs continuously, unlike ``FileProvider``, it conforms to Service Lifecycle's [`Service`](https://swiftpackageindex.com/swift-server/swift-service-lifecycle/documentation/servicelifecycle/service) protocol, and must be run inside a [`ServiceGroup`](https://swiftpackageindex.com/swift-server/swift-service-lifecycle/documentation/servicelifecycle/servicegroup).

These existing file providers simplify the task of adding support for a new file format to Swift Configuration by only requiring you to implement the parsing logic wrapped in a type conforming to ``FileConfigSnapshot``.

For example, a hypothetical TOML file provider could be implemented the following way:

```swift
import Configuration

/// A snapshot parsed from TOML data.
public struct TOMLSnapshot: FileConfigSnapshot {

    /// Parsing options for TOML files.
    public struct ParsingOptions: FileParsingOptions {
        public var secretsSpecifier: SecretsSpecifier<String, any Sendable>

        public init(secretsSpecifier: SecretsSpecifier<String, any Sendable> = .none) {
            self.secretsSpecifier = secretsSpecifier
        }

        public static var `default`: Self { .init() }
    }
    
    /// Parsed values from the TOML file.
    ///
    /// Does not need to be stored as a dictionary, use whatever internal storage is most
    /// natural for the format.
    private let values: [String: ConfigValue]

    /// The name of the provider that created the snapshot.
    public let providerName: String

    /// First requirement: an initializer that parses the provided file data into the internal values.
    ///
    /// This is the format-specific logic.
    public init(data: RawSpan, providerName: String, parsingOptions: ParsingOptions) throws {
        self.providerName = providerName
        
        // Parse the TOML data using your preferred TOML library.
        let parsed = try parseTOML(data)

        // Flatten nested keys using dot notation.
        //
        // Note that you don't need to flatten the keys internally, this is just an example
        // of an internal representation.
        var flatValues: [String: ConfigValue] = [:]
        flattenTOML(parsed, prefix: "", into: &flatValues, secretsSpecifier: parsingOptions.secretsSpecifier)
        
        self.values = flatValues
    }

    /// Second requirement: a value that returns a value for the provided key.
    public func value(forKey key: AbsoluteConfigKey, type: ConfigType) throws -> LookupResult {
        // Use dot-separated encoding for hierarchical keys.
        let encodedKey = key.components.joined(separator: ".")
        guard let value = values[encodedKey] else {
            return LookupResult(encodedKey: encodedKey, value: nil)
        }
        guard value.content.type == type else {
            throw // ... a type mismatch error.
        }
        return LookupResult(encodedKey: encodedKey, value: value)
    }
}

extension TOMLSnapshot: CustomStringConvertible {
    public var description: String {
        "\(providerName)[\(values.count) values]"
    }
}

extension TOMLSnapshot: CustomDebugStringConvertible {
    public var debugDescription: String {
        let sorted = values.keys.sorted().map { "\($0)=\(values[$0]!)" }.joined(separator: ", ")
        return "\(providerName)[\(values.count) values: \(sorted)]"
    }
}
```

Once implemented, use your snapshot with the built-in file providers:

```swift
// Immutable file provider.
let provider = try await FileProvider<TOMLSnapshot>(filePath: "/etc/config.toml")

// Reloading file provider.
let reloadingProvider = try await ReloadingFileProvider<TOMLSnapshot>(
    filePath: "/etc/config.toml",
    pollInterval: .seconds(30)
)
```

> Tip: For examples of file snapshot types, check out ``JSONSnapshot`` and ``YAMLSnapshot``.

### Implement an immutable provider

For non-file-based providers that represent immutable data in memory, the implementation is similar to the file snapshot implementation:

1. Implement a custom snapshot type with its ``ConfigSnapshot/value(forKey:type:)`` method, conforming to ``ConfigSnapshot``.
2. Implement the provider type, conforming to ``ConfigProvider``.
3. For the "fetch" method, just call the equivalent "get" method. This is acceptable, as "fetch" is supposed to reach out to the source of truth, and in the case of this provider, the in-memory representation is the source of truth.
4. For the "watch" methods, use the helpers that emit the current value or snapshot once, and never emit another update. This is a valid implementation of "watch" in an immutable provider:
    - ``ConfigProvider/watchValueFromValue(forKey:type:updatesHandler:)``
    - ``ConfigProvider/watchSnapshotFromSnapshot(updatesHandler:)``

Here's an example of a provider that reads from a dictionary:

```swift
/// A provider that serves values from a static dictionary.
public struct ImmutableDictionaryProvider: ConfigProvider, Sendable {

    /// The internal state of the provider: stores the initial dictionary of values
    /// and never changes.
    private let currentSnapshot: ImmutableDictionarySnapshot
    
    public init(name: String, values: [String: ConfigValue]) {
        self.currentSnapshot = ImmutableDictionarySnapshot(
            providerName: "ImmutableDictionaryProvider[\(name)]",
            values: values
        )
    }
    
    public func value(forKey key: AbsoluteConfigKey, type: ConfigType) throws -> LookupResult {
        try currentSnapshot.value(forKey: key, type: type)
    }
    
    // In immutable providers, fetch just returns the cached value.
    public func fetchValue(forKey key: AbsoluteConfigKey, type: ConfigType) async throws -> LookupResult {
        try value(forKey: key, type: type)
    }
    
    // Use the helper method for immutable providers.
    public func watchValue<Return: ~Copyable>(
        forKey key: AbsoluteConfigKey,
        type: ConfigType,
        updatesHandler: (_ updates: ConfigUpdatesAsyncSequence<Result<LookupResult, any Error>, Never>) async throws -> Return
    ) async throws -> Return {
        try await watchValueFromValue(forKey: key, type: type, updatesHandler: updatesHandler)
    }
    
    // Return the current snapshot.
    public func snapshot() -> any ConfigSnapshot {
        currentSnapshot
    }
    
    // Use the helper method for immutable providers.
    public func watchSnapshot<Return: ~Copyable>(
        updatesHandler: (_ updates: ConfigUpdatesAsyncSequence<any ConfigSnapshot, Never>) async throws -> Return
    ) async throws -> Return {
        try await watchSnapshotFromSnapshot(updatesHandler: updatesHandler)
    }
}

struct ImmutableDictionarySnapshot: ConfigSnapshot {
    let providerName: String
    let values: [String: ConfigValue]
    
    func value(forKey key: AbsoluteConfigKey, type: ConfigType) throws -> LookupResult {
        let encodedKey = key.description
        guard let value = values[encodedKey] else {
            return LookupResult(encodedKey: encodedKey, value: nil)
        }
        guard value.content.type == type else {
            throw // ... emit a type mismatch error.
        }
        return LookupResult(encodedKey: encodedKey, value: value)
    }
}
```

> Tip: For examples of immutable providers, check out ``EnvironmentVariablesProvider``, ``CommandLineArgumentsProvider``, and ``InMemoryProvider``.

### Implement a dynamic provider

For providers that retrieve configuration from remote servers or files on disk, implement meaningful "fetch" behavior that contacts the authoritative source. For providers whose internal representation might change over time, also implement "watch" behavior.

```swift
/// A provider that fetches configuration from a remote HTTP endpoint
/// and periodically re-fetches the data.
public final class RemoteConfigProvider: ConfigProvider {
    
    /// The current internal representation of the provider.
    private struct Storage {

        /// The latest, successfully fetched snapshot.
        var currentSnapshot: RemoteConfigSnapshot

        /// The ETag returned by the server to allow using If-None-Match + 304 Not Modified.
        var lastETag: String?

        /// Keeps track of active `watchValue` callers.
        var valueWatchers: [AbsoluteConfigKey: [UUID: AsyncStream<Result<LookupResult, any Error>>.Continuation]]

        /// Keeps track of active `watchSnapshot` callers.
        var snapshotWatchers: [UUID: AsyncStream<any ConfigSnapshot>.Continuation]
    }

    private let storage: Mutex<Storage>
    private let endpoint: URL
    private let pollInterval: Duration
    
    public let providerName: String

    public init(endpoint: URL, pollInterval: Duration = .seconds(60)) async throws {
        self.endpoint = endpoint
        self.pollInterval = pollInterval
        self.providerName = "RemoteConfigProvider[\(endpoint.host ?? "unknown")]"
        guard let snapshot = try await fetchChangedSnapshot(etag: nil) else {
            throw // ... throw an error, as without an etag, a snapshot should be returned.
        }
        self.storage = Mutex(Storage(currentSnapshot: snapshot, lastETag: nil, valueWatchers: [:], snapshotWatchers: [:]))
    }

    // Fetches from the remote endpoint by providing the current ETag and
    // returns nil if the remote data hasn't changed.
    private static func fetchChangedSnapshot(etag: String?) async throws -> RemoteConfigSnapshot? {
        // ...
    }

    private func refreshCache() async throws {
        // 1. Call fetchChangedSnapshot with the current etag.
        // 2a. If unchanged, return.
        // 2b. If a changed snapshot is returned, notify all active watchers.
    }

    public func value(forKey key: AbsoluteConfigKey, type: ConfigType) throws -> LookupResult {
        try storage.withLock { try $0.value(forKey: key, type: type) }
    }
    
    public func fetchValue(forKey key: AbsoluteConfigKey, type: ConfigType) async throws -> LookupResult {
        // Ensure you have the latest data.
        try await refreshCache()
        return try value(forKey: key, type: type)
    }
    
    public func watchValue<Return: ~Copyable>(
        forKey key: AbsoluteConfigKey,
        type: ConfigType,
        updatesHandler: (_ updates: ConfigUpdatesAsyncSequence<Result<LookupResult, any Error>, Never>) async throws -> Return
    ) async throws -> Return {
        let (stream, continuation) = AsyncStream<Result<LookupResult, any Error>>
            .makeStream(bufferingPolicy: .bufferingNewest(1))
        let id = UUID()
        
        // Register the watcher and get the initial value.
        let initialValue: Result<LookupResult, any Error> = storage.withLock { storage in
            storage.valueWatchers[key, default: [:]][id] = continuation
            return Result { try lookupValue(key, type: type, in: storage.values) }
        }
        
        // Clean up when the handler completes.
        defer {
            storage.withLock { storage in
                storage.valueWatchers[key, default: [:]][id] = nil
            }
        }
        
        // Emit the initial value immediately.
        continuation.yield(initialValue)
        return try await updatesHandler(ConfigUpdatesAsyncSequence(stream))
    }

    // Implement watchSnapshot the same way, just emitting every time the snapshot
    // changes.
}

extension RemoteConfigProvider: Service {
    public func run() async throws {
        for try await _ in AsyncTimerSequence(interval: pollInterval, clock: .continuous).cancelOnGracefulShutdown() {
            do {
                try await refreshCache()
            } catch {
                // Log the error, but continue running the loop
            }
        }
    }
}

struct RemoteConfigSnapshot: ConfigSnapshot {

    var values: [String: ConfigValue]

    func value(forKey key: AbsoluteConfigKey, type: ConfigType) throws -> LookupResult {
        // ... return the current value from `values` like in previous examples.
    }
}
```

> Tip: For examples of dynamic providers, check out ``ReloadingFileProvider`` and ``MutableInMemoryProvider``.

### Integrate with Service Lifecycle

Providers that need background tasks (such as polling or maintaining connections) should conform to the `Service` protocol from [swift-service-lifecycle](https://github.com/swift-server/swift-service-lifecycle):

```swift
import ServiceLifecycle

extension DynamicProvider: Service {
    public func run() async throws {
        // Run background polling until graceful shutdown.
        for try await _ in AsyncTimerSequence(interval: .seconds(15), clock: .continuous)
            .cancelOnGracefulShutdown() 
        {
            do {
                try await refreshAndNotify()
            } catch {
                // Log error and continue polling.
            }
        }
    }
}

// Usage:
let provider = DynamicProvider(name: "remote")
let reader = ConfigReader(provider: provider)
// Pass the reader to business logic that runs in a separate service.

let businessLogicService = ...

let serviceGroup = ServiceGroup(
    services: [provider, businessLogicService], 
    logger: logger
)
try await serviceGroup.run()
```

### Test your provider

Use `ProviderCompatTest` from the `ConfigurationTesting` module to verify your provider implementation. Your provider must contain specific test data for the tests to pass:

```swift
import Testing
import Configuration
import ConfigurationTesting

@Test func testMyProvider() async throws {
    // Create your provider with the required test data.
    let provider = MyProvider(values: [
        "string": ConfigValue(.string("Hello"), isSecret: false),
        "other.string": ConfigValue(.string("Other Hello"), isSecret: false),
        "int": ConfigValue(.int(42), isSecret: false),
        "other.int": ConfigValue(.int(24), isSecret: false),
        "double": ConfigValue(.double(3.14), isSecret: false),
        "other.double": ConfigValue(.double(2.72), isSecret: false),
        "bool": ConfigValue(.bool(true), isSecret: false),
        "other.bool": ConfigValue(.bool(false), isSecret: false),
        // ... additional required test values (see ProviderCompatTest documentation)
    ])
    
    let test = ProviderCompatTest(provider: provider)
    try await test.runTest()
}
```

> Tip: For file-based providers, create a test fixture file containing the required test data and load it during tests using temporary files or bundle resources.

### Naming recommendations

Use the `Provider` suffix for all providers.

When implementing both an immutable and a dynamic variant, use the following prefixes:

- The immutable variant should have no prefix, for example, `InMemoryProvider`.
- The dynamic variant should have the `Reloading` prefix when reading from disk, and the `Refetching` prefix when fetching from the network.

> Note: You don't have to follow these recommendations, always prefer to follow correct Swift API design guidelines, whever in conflict with the above recommendations.

### Thread safety considerations

All providers must be `Sendable` because configuration can be accessed from multiple isolation domains. Follow these patterns:

- **Immutable providers**: Use a trivial `struct` for providers whose values never change.
- **Mutex-based providers**: Use a final `class` for mutable providers.
