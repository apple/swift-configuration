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

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// A type that provides read-only access to configuration values from underlying providers.
///
/// Use `ConfigReader` to access configuration values from various sources like environment variables,
/// JSON files, or in-memory stores. The reader supports provider hierarchies, key scoping, and
/// access reporting for debugging configuration usage.
///
/// ## Usage
///
/// To read configuration values, create a config reader with one or more providers:
///
/// ```swift
/// let config = ConfigReader(provider: EnvironmentVariablesProvider())
/// let httpTimeout = config.int(forKey: "http.timeout", default: 60)
/// ```
///
/// ### Using multiple providers
///
/// Create a hierarchy of providers by passing an array to the initializer. The reader queries
/// providers in order, using the first non-nil value it finds:
///
/// ```swift
/// do {
///     let config = ConfigReader(providers: [
///         // First, check environment variables
///         EnvironmentVariablesProvider(),
///         // Then, check a JSON config file
///         try await JSONProvider(filePath: "/etc/config.json"),
///         // Finally, fall back to in-memory defaults
///         InMemoryProvider(values: [
///             "http.timeout": 60,
///         ])
///     ])
///
///     // Uses the first provider that has a value for "http.timeout"
///     let timeout = config.int(forKey: "http.timeout", default: 15)
/// } catch {
///     print("Failed to create JSON provider: \(error)")
/// }
/// ```
///
/// The `get` and `fetch` methods query providers sequentially, while the `watch` method
/// monitors all providers in parallel and returns the first non-nil value from the latest
/// results.
///
/// ### Creating scoped readers
///
/// Create a scoped reader to access nested configuration sections without repeating key prefixes.
/// This is useful for passing configuration to specific components.
///
/// Given this JSON configuration:
///
/// ```json
/// {
///   "http": {
///     "timeout": 60
///   }
/// }
/// ```
///
/// Create a scoped reader for the HTTP section:
///
/// ```swift
/// let httpConfig = config.scoped(to: "http")
/// let timeout = httpConfig.int(forKey: "timeout")  // Reads "http.timeout"
/// ```
///
/// ### Understanding config keys
///
/// The library accesses configuration values using config keys that represent a hierarchical path to the value.
/// Internally, the library represents a key as a list of string components, such as `["http", "timeout"]`.
///
/// ### Using configuration context
///
/// Provide additional context to help providers return more specific values. In the following example
/// with a configuration that includes repeated configurations per "upstream" side, the value returned is
/// potentially constrained to the configuration with the matching context:
///
/// ```swift
/// let httpTimeout = config.int(
///     forKey: "http.timeout",
///     context: ["upstream": "example.com"],
///     default: 60
/// )
/// ```
///
/// Providers can use this context to return specialized values or fall back to generic ones.
/// Some providers may ignore context and use only the key path.
///
/// ### Automatic type conversion
///
/// The library can automatically convert string configuration values to other types using the `as:` parameter.
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
/// let apiUrl = config.string(forKey: "api.url", as: URL.self)
/// let requestId = config.string(
///     forKey: "request.id",
///     as: UUID.self
/// )
///
/// // Custom enum conversion (RawRepresentable<String>)
/// enum LogLevel: String {
///     case debug, info, warning, error
/// }
/// let logLevel = config.string(
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
/// let dbUrl = config.string(
///     forKey: "database.url",
///     as: DatabaseURL.self
/// )
/// ```
///
/// ### Customizing key decoding
///
/// By default, config keys use a dot-separated notation (`http.timeout` becomes `["http", "timeout"]`).
/// The ``ConfigKeyDecoder`` handles this parsing, with ``ConfigReader`` using
/// ``ConfigKeyDecoder/dotSeparated`` by default.
///
/// To use different key separators, provide a custom decoder:
///
/// ```swift
/// let config = ConfigReader(keyDecoder: .colonSeparated, provider: provider)
/// let httpTimeout = config.int(forKey: "http:timeout", default: 60)
/// ```
///
/// ### How providers encode keys
///
/// Each ``ConfigProvider`` interprets config keys according to its data source format.
/// For example, ``EnvironmentVariablesProvider`` converts `["http", "timeout"]` to the
/// environment variable name `HTTP_TIMEOUT` by uppercasing components and joining with underscores.
///
/// ### Monitoring configuration access
///
/// Use an access reporter to track which configuration values your application reads.
/// The reporter receives ``AccessEvent`` instances containing the requested key, calling code location,
/// returned value, and source provider.
///
/// This helps debug configuration issues and to discover the config dependencies in your codebase.
///
/// > Tip: Set the `CONFIG_ACCESS_LOG_FILE` environment variable to automatically log all configuration access to a file: `CONFIG_ACCESS_LOG_FILE=/tmp/config-access.log`
///
/// ### Protecting sensitive values
///
/// Mark sensitive configuration values as secrets to prevent logging by access loggers.
/// Both config readers and providers can set the `isSecret` property. When either marks a
/// value as sensitive, ``AccessReporter`` instances should not log the raw value.
///
/// ### Configuration context
///
/// Configuration context supplements the configuration key components with extra metadata
/// that providers can use to refine value lookups or return more specific results.
/// Context is particularly useful for scenarios where the same configuration key might
/// need different values based on runtime conditions.
///
/// Create context using dictionary literal syntax with automatic type inference:
///
/// ```swift
/// let context: [String: ConfigContextValue] = [
///     "environment": "production",
///     "region": "us-west-2",
///     "timeout": 30,
///     "retryEnabled": true
/// ]
/// ```
///
/// #### Provider behavior
///
/// Not all providers use context information. Providers that support context can:
/// - Return specialized values based on context keys.
/// - Fall back to generic values when context doesn't match.
/// - Ignore context entirely and use only the key path.
///
/// For example, a provider might return different database connection strings
/// based on the environment context:
///
/// ```swift
/// let dbConfig = config.string(
///     forKey: "database.url",
///     context: ["environment": "staging"],
///     default: "localhost:5432"
/// )
/// ```
///
/// ### Error handling behavior
///
/// The config reader handles provider errors differently based on the method type:
///
/// - **Get and watch methods**: Gracefully handle errors by returning `nil` or default values,
///   except for "required" variants which rethrow errors.
/// - **Fetch methods**: Always rethrow both provider and conversion errors.
/// - **Required methods**: Rethrow all errors without fallback behavior.
///
/// The library reports all provider errors to the access reporter through the `providerResults` array,
/// even when handled gracefully.
public struct ConfigReader: Sendable {

    /// The key prefix prepended to all configuration lookups.
    ///
    /// When set, allows accessing nested values with shorter keys. For example,
    /// with the prefix `outer.middle`, you can access the key`outer.middle.inner` using just `inner`.
    let keyPrefix: AbsoluteConfigKey?

    /// The underlying storage that is shared with all the transitive child configs created
    /// from this one.
    private final class Storage: Sendable {

        /// The decoder that converts string keys into config key arrays.
        ///
        /// For example, converts the string`foo.bar.baz` into its array representation `["foo", "bar", "baz"]`.
        let keyDecoder: any ConfigKeyDecoder

        /// The underlying multi provider.
        let provider: MultiProvider

        /// The reporter of access events.
        let accessReporter: (any AccessReporter)?

        /// Creates a storage instance.
        /// - Parameters:
        ///   - keyDecoder: The decoder for converting string keys to config keys.
        ///   - provider: The multi-provider that manages the provider hierarchy.
        ///   - accessReporter: The reporter for configuration access events.
        init(
            keyDecoder: some ConfigKeyDecoder,
            provider: MultiProvider,
            accessReporter: (any AccessReporter)?
        ) {
            self.keyDecoder = keyDecoder
            self.provider = provider
            self.accessReporter = accessReporter
        }
    }

    /// The underlying storage that is shared with all the transitive child configs created from this one.
    private let storage: Storage

    /// Creates a new config reader with shared storage.
    /// - Parameters:
    ///   - keyPrefix: The key prefix prepended to all configuration lookups.
    ///   - storage: The shared storage instance used by this reader and any scoped readers created from it.
    private init(
        keyPrefix: AbsoluteConfigKey?,
        storage: Storage
    ) {
        self.keyPrefix = keyPrefix
        self.storage = storage
    }

    /// Creates a config reader with multiple providers.
    /// - Parameters:
    ///   - keyDecoder: The decoder that converts string keys to config keys.
    ///   - providers: The configuration providers, queried in order until a value is found.
    ///   - accessReporter: The reporter for configuration access events.
    public init(
        keyDecoder: some ConfigKeyDecoder = .dotSeparated,
        providers: [any ConfigProvider],
        accessReporter: (any AccessReporter)? = nil
    ) {
        var reporter = accessReporter as (any AccessReporter)?
        do {
            if let fileReporter = try FileAccessLogger.detectedFromEnvironment() {
                if let accessReporter {
                    reporter = BroadcastingAccessReporter(upstreams: [accessReporter, fileReporter])
                } else {
                    reporter = fileReporter
                }
            }
        } catch {
            printToStderr(
                "Failed to create a file access reporter requested by the environment variable CONFIG_ACCESS_LOG_FILE, error: \(error)"
            )
        }
        self.init(
            keyPrefix: nil,
            storage: .init(
                keyDecoder: keyDecoder,
                provider: MultiProvider(providers: providers),
                accessReporter: reporter
            )
        )
    }
}

extension ConfigReader {

    /// Creates a config reader with a single provider.
    /// - Parameters:
    ///   - keyDecoder: The decoder that converts string keys to config keys.
    ///   - provider: The configuration provider.
    ///   - accessReporter: The reporter for configuration access events.
    public init(
        keyDecoder: some ConfigKeyDecoder = .dotSeparated,
        provider: some ConfigProvider,
        accessReporter: (any AccessReporter)? = nil
    ) {
        self.init(
            keyDecoder: keyDecoder,
            providers: [provider],
            accessReporter: accessReporter
        )
    }

    /// Creates a scoped config reader.
    /// - Parameters:
    ///   - scopedKey: The key components to append to the current key prefix.
    ///   - parent: The parent config reader from which to create the scoped reader.
    ///   - keyDecoderOverride: An optional key decoder that replaces the parent's decoder.
    private init(scopedKey: ConfigKey, parent: ConfigReader, keyDecoderOverride: (any ConfigKeyDecoder)?) {
        let storage: Storage
        if let keyDecoderOverride {
            storage = .init(
                keyDecoder: keyDecoderOverride,
                provider: parent.storage.provider,
                accessReporter: parent.storage.accessReporter
            )
        } else {
            storage = parent.storage
        }
        self.init(
            keyPrefix: parent.keyPrefix.appending(scopedKey),
            storage: storage
        )
    }

    /// Returns a scoped config reader with the specified key appended to the current prefix.
    ///
    /// ```swift
    /// let httpConfig = config.scoped(to: ConfigKey(["http", "client"]))
    /// let timeout = httpConfig.int(forKey: "timeout", default: 30) // Reads "http.client.timeout"
    /// ```
    ///
    /// - Parameters:
    ///   - configKey: The key components to append to the current key prefix.
    ///   - keyDecoderOverride: An optional key decoder that replaces the current decoder.
    /// - Returns: A config reader for accessing values within the specified scope.
    public func scoped(to configKey: ConfigKey, keyDecoderOverride: (any ConfigKeyDecoder)? = nil) -> ConfigReader {
        ConfigReader(
            scopedKey: configKey,
            parent: self,
            keyDecoderOverride: keyDecoderOverride
        )
    }

    /// Returns a scoped config reader with the specified string key appended to the current prefix.
    ///
    /// ```swift
    /// let dbConfig = config.scoped(to: "database")
    /// let host = dbConfig.string(forKey: "host", default: "localhost") // Reads "database.host"
    /// ```
    ///
    /// - Parameters:
    ///   - key: The string key to decode and append to the current key prefix.
    ///   - context: Additional context used when decoding the key.
    ///   - keyDecoderOverride: An optional key decoder that replaces the current decoder.
    /// - Returns: A config reader for accessing values within the specified scope.
    public func scoped(
        to key: String,
        context: [String: ConfigContextValue] = [:],
        keyDecoderOverride: (any ConfigKeyDecoder)? = nil
    ) -> ConfigReader {
        ConfigReader(
            scopedKey: (keyDecoderOverride ?? keyDecoder).decode(key, context: context),
            parent: self,
            keyDecoderOverride: keyDecoderOverride
        )
    }
}

// MARK: - Internal conveniences

extension ConfigReader {

    /// The decoder the library uses to convert string keys into config keys.
    var keyDecoder: any ConfigKeyDecoder {
        storage.keyDecoder
    }

    /// The multi-provider that manages the hierarchy of configuration providers.
    var provider: MultiProvider {
        storage.provider
    }

    /// The reporter that receives configuration access events.
    var accessReporter: (any AccessReporter)? {
        storage.accessReporter
    }
}

// MARK: - Errors

/// An error thrown by Configuration module types.
///
/// These errors indicate issues with configuration value retrieval or conversion.
package enum ConfigError: Error, CustomStringConvertible, Equatable {

    /// A required configuration value was not found in any provider.
    case missingRequiredConfigValue(AbsoluteConfigKey)

    /// A configuration value could not be converted to the expected type.
    case configValueNotConvertible(name: String, type: ConfigType)

    /// A configuration value could not be cast to the expected type.
    case configValueFailedToCast(name: String, type: String)

    package var description: String {
        switch self {
        case .missingRequiredConfigValue(let key):
            return "Missing required config value for key: \(key)."
        case .configValueNotConvertible(let name, let type):
            return "Config value for key '\(name)' failed to convert to type \(type)."
        case .configValueFailedToCast(let name, let type):
            return "Config value for key '\(name)' failed to cast to type \(type)."
        }
    }
}
