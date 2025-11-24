//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftConfiguration open source project
//
// Copyright (c) 2025 Apple Inc. and the SwiftConfiguration project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftConfiguration project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Synchronization

/// A container type for reading config values from snapshots.
///
/// A config snapshot reader provides read-only access to config values stored in an underlying snapshot.
/// Unlike ``ConfigReader``, which can access live, changing config values from providers, a snapshot reader
/// works with a fixed, immutable snapshot of the configuration data.
///
/// ## Usage
///
/// Get a ``ConfigSnapshotReader`` from a ``ConfigReader`` by using ``ConfigReader/snapshot()``
/// to retrieve a snapshot. All values in the snapshot are guaranteed to be from the same point in time:
/// ```swift
/// // Get a snapshot from a ConfigReader
/// let config = ConfigReader(provider: EnvironmentVariablesProvider())
/// let snapshot = config.snapshot()
/// // Use snapshot to read config values
/// let cert = snapshot.string(forKey: "cert")
/// let privateKey = snapshot.string(forKey: "privateKey")
/// // Ensures that both values are coming from the same
/// // underlying snapshot and that a provider didn't change
/// // its internal state between the two `string(...)` calls.
/// let identity = MyIdentity(cert: cert, privateKey: privateKey)
/// ```
///
/// Or you can watch for snapshot updates using the ``ConfigReader/watchSnapshot(fileID:line:updatesHandler:)``:
///
/// ```swift
/// try await config.watchSnapshot { snapshots in
///     for await snapshot in snapshots {
///         // Process each new configuration snapshot
///         let cert = snapshot.string(forKey: "cert")
///         let privateKey = snapshot.string(forKey: "privateKey")
///         // Ensures that both values are coming from the same
///         // underlying snapshot and that a provider didn't change
///         // its internal state between the two `string(...)` calls.
///         let newCert = MyCert(cert: cert, privateKey: privateKey)
///         print("Certificate was updated: \(newCert.redactedDescription)")
///     }
/// }
/// ```
///
/// ### Scoping
///
/// Like `ConfigReader`, you can set a key prefix on the config snapshot reader, allowing all config lookups
/// to prepend a prefix to the keys, which lets you pass a scoped snapshot reader to nested components.
///
/// ```swift
/// let httpConfig = snapshotReader.scoped(to: "http")
/// let timeout = httpConfig.int(forKey: "timeout")
/// // Reads from "http.timeout" in the snapshot
/// ```
///
/// ### Config keys and context
///
/// The library requests config values using a canonical "config key", that represents a key path.
/// You can provide additional context that was used by some providers when the snapshot was created.
///
/// ```swift
/// let httpTimeout = snapshotReader.int(
///     forKey: ConfigKey("http.timeout", context: ["upstream": "example.com"]),
///     default: 60
/// )
/// ```
///
/// ### Automatic type conversion
///
/// String configuration values can be automatically converted to other types using the `as:` parameter.
/// This works with:
/// - String-backed enum types, as they conform to `RawRepresentable<String>`.
/// - Types that you explicitly conform to ``ExpressibleByConfigString``.
/// - Built-in types that already conform to ``ExpressibleByConfigString``:
///   - `SystemPackage.FilePath` - Converts from file paths.
///   - `Foundation.URL` - Converts from URL strings.
///   - `Foundation.UUID` - Converts from UUID strings.
///   - `Foundation.Date` - Converts from ISO8601 date strings.
///
/// ```swift
/// // Built-in type conversion
/// let apiUrl = snapshot.string(
///     forKey: "api.url",
///     as: URL.self
/// )
/// let requestId = snapshot.string(
///     forKey: "request.id",
///     as: UUID.self
/// )
///
/// // Custom enum conversion (RawRepresentable<String>)
/// enum LogLevel: String {
///     case debug, info, warning, error
/// }
/// let logLevel = snapshot.string(
///     forKey: "logging.level",
///     as: LogLevel.self,
///     default: .info
/// )
///
/// // Custom type conversion (ExpressibleByConfigString)
/// struct DatabaseURL: ExpressibleByConfigString {
///     let url: URL
///
///     init?(configString: String) {
///         guard let url = URL(string: configString) else { return nil }
///         self.url = url
///     }
///
///     var description: String { url.absoluteString }
/// }
/// let dbUrl = snapshot.string(
///     forKey: "database.url",
///     as: DatabaseURL.self
/// )
/// ```
///
/// ### Access reporting
///
/// When reading from a snapshot, access events are reported to the access reporter from the
/// original config reader. This helps debug which config values are accessed, even when
/// reading from snapshots.
@available(Configuration 1.0, *)
public struct ConfigSnapshotReader: Sendable {

    /// The prefix of the key for accessing config values in the provider.
    ///
    /// For example, for a value at key path `outer.middle.inner`, creating
    /// a config with the key prefix `outer.middle` allows querying
    /// the value just using the key `inner` at the call site.
    let keyPrefix: AbsoluteConfigKey?

    /// The underlying storage that is shared with any transitive child configs created
    /// from this one.
    final class Storage: Sendable {

        /// The underlying multi snapshot.
        let snapshot: MultiSnapshot

        /// The reporter of access events.
        let accessReporter: (any AccessReporter)?

        /// Creates a storage instance.
        /// - Parameters:
        ///   - snapshot: The underlying multi snapshot.
        ///   - accessReporter: The reporter of access events.
        init(
            snapshot: MultiSnapshot,
            accessReporter: (any AccessReporter)?
        ) {
            self.snapshot = snapshot
            self.accessReporter = accessReporter
        }
    }

    /// The underlying storage that is shared with any transitive child readers created from this one.
    private var storage: Storage

    /// The underlying multi snapshot.
    private var snapshot: MultiSnapshot {
        storage.snapshot
    }

    /// The reporter of access events.
    private var accessReporter: (any AccessReporter)? {
        storage.accessReporter
    }

    /// Creates a reader.
    /// - Parameters:
    ///   - keyPrefix: The prefix of the key for accessing config values in the snapshot.
    ///   - storage: The underlying storage that is shared with all the transitive child readers
    ///     created from this one.
    init(
        keyPrefix: AbsoluteConfigKey?,
        storage: Storage
    ) {
        self.keyPrefix = keyPrefix
        self.storage = storage
    }

    /// Creates a scoped reader.
    /// - Parameters:
    ///   - scopedKey: The key to append to the current key prefix.
    ///   - parent: The parent reader from which to create a scoped reader.
    private init(scopedKey: ConfigKey, parent: ConfigSnapshotReader) {
        self.init(
            keyPrefix: parent.keyPrefix.appending(scopedKey),
            storage: parent.storage
        )
    }

    /// Returns a scoped snapshot reader by appending the provided key to the current key prefix.
    ///
    /// Use this method to create a reader that accesses a subset of the configuration.
    ///
    /// ```swift
    /// let httpConfig = snapshotReader.scoped(to: ["client", "http"])
    /// let timeout = httpConfig.int(forKey: "timeout") // Reads from "client.http.timeout" in the snapshot
    /// ```
    ///
    /// - Parameters configKey: The key to append to the current key prefix.
    /// - Returns: A reader for accessing scoped values.
    public func scoped(to configKey: ConfigKey)
        -> ConfigSnapshotReader
    {
        ConfigSnapshotReader(
            scopedKey: configKey,
            parent: self
        )
    }
}

@available(Configuration 1.0, *)
extension ConfigReader {
    /// Returns a snapshot of the current configuration state.
    ///
    /// The snapshot reader provides read-only access to the configuration's state
    /// at the time the method was called.
    ///
    /// ```swift
    /// let snapshot = config.snapshot()
    /// // Use snapshot to read config values
    /// let cert = snapshot.string(forKey: "cert")
    /// let privateKey = snapshot.string(forKey: "privateKey")
    /// // Ensures that both values are coming from the same underlying snapshot and that a provider
    /// // didn't change its internal state between the two `string(...)` calls.
    /// let identity = MyIdentity(cert: cert, privateKey: privateKey)
    /// ```
    ///
    /// - Returns: The snapshot.
    public func snapshot() -> ConfigSnapshotReader {
        let multiSnapshot = provider.snapshot()
        let snapshotReader = ConfigSnapshotReader(
            keyPrefix: keyPrefix,
            storage: .init(
                snapshot: multiSnapshot,
                accessReporter: accessReporter
            )
        )
        return snapshotReader
    }

    /// Watches the configuration for changes.
    ///
    /// This method watches the configuration for changes and provides a stream of snapshots
    /// to the handler closure. Each snapshot represents the configuration state at a specific point in time.
    ///
    /// ```swift
    /// try await config.watchSnapshot { snapshots in
    ///     for await snapshot in snapshots {
    ///         // Process each new configuration snapshot
    ///         let cert = snapshot.string(forKey: "cert")
    ///         let privateKey = snapshot.string(forKey: "privateKey")
    ///         // Ensures that both values are coming from the same underlying snapshot and that a provider
    ///         // didn't change its internal state between the two `string(...)` calls.
    ///         let newCert = MyCert(cert: cert, privateKey: privateKey)
    ///         print("Certificate was updated: \(newCert.redactedDescription)")
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - fileID: The file where this method is called from.
    ///   - line: The line where this method is called from.
    ///   - updatesHandler: A closure that receives an async sequence of `ConfigSnapshotReader` instances.
    /// - Returns: The value returned by the handler.
    /// - Throws: Any error thrown by the handler.
    public func watchSnapshot<Return: ~Copyable>(
        fileID: String = #fileID,
        line: UInt = #line,
        updatesHandler: (ConfigUpdatesAsyncSequence<ConfigSnapshotReader, Never>) async throws -> Return
    ) async throws -> Return {
        try await provider.watchSnapshot { updates in
            try await updatesHandler(
                ConfigUpdatesAsyncSequence(
                    updates
                        .map { multiSnapshot in
                            ConfigSnapshotReader(
                                keyPrefix: keyPrefix,
                                storage: .init(
                                    snapshot: multiSnapshot,
                                    accessReporter: accessReporter
                                )
                            )
                        }
                )
            )
        }
    }
}

@available(Configuration 1.0, *)
extension ConfigSnapshotReader {
    /// Gets a value from the snapshot.
    ///
    /// - Parameters:
    ///   - key: The config key to get the value for.
    ///   - type: The expected type of the value.
    ///   - isSecret: Whether the value is a secret.
    ///   - unwrap: A closure that unwraps the config content to the desired type.
    ///   - wrap: A closure that wraps the value in config content.
    ///   - fileID: The file ID where this method was called from.
    ///   - line: The line number where this method was called from.
    /// - Returns: The unwrapped value if found and convertible, or nil otherwise.
    internal func value<Value>(
        forKey key: ConfigKey,
        type: ConfigType,
        isSecret: Bool,
        unwrap: (ConfigContent) throws -> Value,
        wrap: (Value) -> ConfigContent,
        fileID: String,
        line: UInt
    ) -> Value? {
        valueFromReader(
            forKey: key,
            type: type,
            isSecret: isSecret,
            keyPrefix: keyPrefix,
            valueClosure: { snapshot.multiValue(forKey: $0, type: $1) },
            accessReporter: accessReporter,
            unwrap: unwrap,
            wrap: wrap,
            fileID: fileID,
            line: line
        )
    }

    /// Gets a value from the snapshot with a default value.
    ///
    /// - Parameters:
    ///   - key: The config key to get the value for.
    ///   - type: The expected type of the value.
    ///   - isSecret: Whether the value is a secret.
    ///   - defaultValue: The default value to return if the value isn't found or can't be converted.
    ///   - unwrap: A closure that unwraps the config content to the desired type.
    ///   - wrap: A closure that wraps the value in config content.
    ///   - fileID: The file ID where this method was called from.
    ///   - line: The line number where this method was called from.
    /// - Returns: The unwrapped value if found and convertible, or the default value otherwise.
    internal func value<Value>(
        forKey key: ConfigKey,
        type: ConfigType,
        isSecret: Bool,
        default defaultValue: Value,
        unwrap: (ConfigContent) throws -> Value,
        wrap: (Value) -> ConfigContent,
        fileID: String,
        line: UInt
    ) -> Value {
        valueFromReader(
            forKey: key,
            type: type,
            isSecret: isSecret,
            default: defaultValue,
            keyPrefix: keyPrefix,
            valueClosure: { snapshot.multiValue(forKey: $0, type: $1) },
            accessReporter: accessReporter,
            unwrap: unwrap,
            wrap: wrap,
            fileID: fileID,
            line: line
        )
    }

    /// Gets a required value from the snapshot.
    ///
    /// - Parameters:
    ///   - key: The config key to get the value for.
    ///   - type: The expected type of the value.
    ///   - isSecret: Whether the value is a secret.
    ///   - unwrap: A closure that unwraps the config content to the desired type.
    ///   - wrap: A closure that wraps the value in config content.
    ///   - fileID: The file ID where this method was called from.
    ///   - line: The line number where this method was called from.
    /// - Returns: The unwrapped value.
    /// - Throws: A `ConfigError` if the value isn't found or can't be converted.
    internal func requiredValue<Value>(
        forKey key: ConfigKey,
        type: ConfigType,
        isSecret: Bool,
        unwrap: (ConfigContent) throws -> Value,
        wrap: (Value) -> ConfigContent,
        fileID: String,
        line: UInt
    ) throws -> Value {
        try requiredValueFromReader(
            forKey: key,
            type: type,
            isSecret: isSecret,
            keyPrefix: keyPrefix,
            valueClosure: { snapshot.multiValue(forKey: $0, type: $1) },
            accessReporter: accessReporter,
            unwrap: unwrap,
            wrap: wrap,
            fileID: fileID,
            line: line
        )
    }

    /// Casts a string value to a `ExpressibleByConfigString` type.
    ///
    /// - Parameters:
    ///   - string: The string to cast.
    ///   - type: The type to cast to.
    ///   - key: The config key for error reporting.
    /// - Returns: The cast value.
    /// - Throws: A `ConfigError` if the string can't be cast to the type.
    internal func cast<Value: ExpressibleByConfigString>(
        _ string: String,
        type: Value.Type,
        key: ConfigKey
    ) throws -> Value {
        guard let typedValue = Value.init(configString: string) else {
            throw ConfigError.configValueFailedToCast(name: keyPrefix.appending(key).description, type: "\(type)")
        }
        return typedValue
    }

    /// Casts a string value to a `RawRepresentable` type with a `String` raw value.
    ///
    /// - Parameters:
    ///   - string: The string to cast.
    ///   - type: The type to cast to.
    ///   - key: The config key for error reporting.
    /// - Returns: The cast value.
    /// - Throws: A `ConfigError` if the string can't be cast to the type.
    internal func cast<Value: RawRepresentable<String>>(
        _ string: String,
        type: Value.Type,
        key: ConfigKey
    ) throws -> Value {
        guard let typedValue = Value.init(rawValue: string) else {
            throw ConfigError.configValueFailedToCast(name: keyPrefix.appending(key).description, type: "\(type)")
        }
        return typedValue
    }

    /// Converts a `ExpressibleByConfigString` value to content.
    ///
    /// - Parameter value: The value to convert.
    /// - Returns: The config content.
    internal func uncast<Value: ExpressibleByConfigString>(
        _ value: Value
    ) -> ConfigContent {
        .string(value.description)
    }

    /// Converts an array of `ExpressibleByConfigString` values to content.
    ///
    /// - Parameter values: The values to convert.
    /// - Returns: The config content.
    internal func uncast<Value: ExpressibleByConfigString>(
        _ values: [Value]
    ) -> ConfigContent {
        .stringArray(values.map(\.description))
    }

    /// Converts a `RawRepresentable` value with a `String` raw value to content.
    ///
    /// - Parameter value: The value to convert.
    /// - Returns: The config content.
    internal func uncast<Value: RawRepresentable<String>>(
        _ value: Value
    ) -> ConfigContent {
        .string(value.rawValue)
    }

    /// Converts an array of `RawRepresentable` values with `String` raw values to content.
    ///
    /// - Parameter values: The values to convert.
    /// - Returns: The config content.
    internal func uncast<Value: RawRepresentable<String>>(
        _ values: [Value]
    ) -> ConfigContent {
        .stringArray(values.map(\.rawValue))
    }
}
