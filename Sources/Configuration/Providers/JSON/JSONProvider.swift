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

#if JSONSupport

public import SystemPackage

// Needs full Foundation for JSONSerialization.
import Foundation

/// A configuration provider that loads values from JSON files.
///
/// This provider reads JSON files from the file system and makes their values
/// available as configuration. The JSON structure is flattened using dot notation,
/// allowing nested objects to be accessed with hierarchical keys.
///
/// The provider loads the JSON file once during initialization and never reloads
/// it, making it a constant provider suitable for configuration that doesn't
/// change during application runtime.
///
/// > Tip: Do you need to watch the JSON files on disk for changes, and reload them automatically? Check out ``ReloadingJSONProvider``.
///
/// ## Package traits
///
/// This provider is guarded by the `JSONSupport` package trait.
///
/// ## Supported JSON types
///
/// The provider supports these JSON value types:
/// - **Strings**: Mapped directly to string configuration values
/// - **Numbers**: Integers, doubles, and booleans
/// - **Arrays**: Homogeneous arrays of strings or numbers
/// - **Objects**: Nested objects are flattened using dot notation
/// - **null**: Ignored (no configuration value is created)
///
/// ## Key flattening
///
/// Nested JSON objects are flattened into dot-separated keys:
///
/// ```json
/// {
///   "database": {
///     "host": "localhost",
///     "port": 5432
///   }
/// }
/// ```
///
/// Becomes accessible as:
/// - `database.host` → `"localhost"`
/// - `database.port` → `5432`
///
/// ## Secret handling
///
/// The provider supports marking values as secret using a ``SecretsSpecifier``.
/// Secret values are automatically redacted in logs and debug output.
///
/// ## Usage
///
/// ```swift
/// // Load from a JSON file
/// let provider = try await JSONProvider(filePath: "/etc/config.json")
/// let config = ConfigReader(provider: provider)
///
/// // Access nested values using dot notation
/// let host = config.string(forKey: "database.host")
/// let port = config.int(forKey: "database.port")
/// let isEnabled = config.bool(forKey: "features.enabled", default: false)
/// ```
///
/// ## Configuration context
///
/// This provider ignores the context passed in ``AbsoluteConfigKey/context``.
/// All keys are resolved using only their component path.
@available(Configuration 1.0, *)
public struct JSONProvider: Sendable {

    /// A snapshot of the internal state.
    private let _snapshot: JSONProviderSnapshot

    /// Creates a new JSON provider by loading the specified file.
    ///
    /// This initializer loads and parses the JSON file synchronously during
    /// initialization. The file must contain a valid JSON object at the root level.
    ///
    /// ```swift
    /// // Load configuration from a JSON file
    /// let provider = try await JSONProvider(
    ///     filePath: "/etc/app-config.json",
    ///     secretsSpecifier: .keyBased { key in
    ///         key.contains("password") || key.contains("secret")
    ///     }
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - filePath: The file system path to the JSON configuration file.
    ///   - bytesDecoder: The decoder used to convert string values to byte arrays.
    ///   - secretsSpecifier: Specifies which configuration values should be treated as secrets.
    /// - Throws: If the file cannot be read or parsed, or if the JSON structure is invalid.
    public init(
        filePath: FilePath,
        bytesDecoder: some ConfigBytesFromStringDecoder = .base64,
        secretsSpecifier: SecretsSpecifier<String, any Sendable> = .none
    ) async throws {
        try await self.init(
            filePath: filePath,
            fileSystem: LocalCommonProviderFileSystem(),
            bytesDecoder: bytesDecoder,
            secretsSpecifier: secretsSpecifier
        )
    }

    /// Creates a new JSON provider using a file path from configuration.
    ///
    /// This convenience initializer reads the JSON file path from another
    /// configuration source, allowing the JSON provider to be configured
    /// through configuration itself.
    ///
    /// ```swift
    /// // Configure JSON provider through environment variables
    /// let envProvider = EnvironmentVariablesProvider()
    /// let config = ConfigReader(provider: envProvider)
    ///
    /// // JSON_FILE_PATH environment variable specifies the file
    /// let jsonProvider = try await JSONProvider(
    ///     config: config.scoped(to: "json")
    /// )
    /// ```
    ///
    /// ## Required configuration keys
    ///
    /// - `filePath` (string): The file path to the JSON configuration file.
    ///
    /// - Parameters:
    ///   - config: The configuration reader containing the file path.
    ///   - bytesDecoder: The decoder used to convert string values to byte arrays.
    ///   - secretsSpecifier: Specifies which configuration values should be treated as secrets.
    /// - Throws: If the file path is missing, or if the file cannot be read or parsed.
    public init(
        config: ConfigReader,
        bytesDecoder: some ConfigBytesFromStringDecoder = .base64,
        secretsSpecifier: SecretsSpecifier<String, any Sendable> = .none
    ) async throws {
        try await self.init(
            filePath: config.requiredString(forKey: "filePath", as: FilePath.self),
            bytesDecoder: bytesDecoder,
            secretsSpecifier: secretsSpecifier
        )
    }

    /// Creates a new provider.
    /// - Parameters:
    ///   - filePath: The path of the JSON file.
    ///   - fileSystem: The underlying file system.
    ///   - bytesDecoder: A decoder of bytes from a string.
    ///   - secretsSpecifier: A secrets specifier in case some of the values should be treated as secret.
    /// - Throws: If the file cannot be read or parsed, or if the JSON structure is invalid.
    internal init(
        filePath: FilePath,
        fileSystem: some CommonProviderFileSystem,
        bytesDecoder: some ConfigBytesFromStringDecoder = .base64,
        secretsSpecifier: SecretsSpecifier<String, any Sendable> = .none
    ) async throws {
        self._snapshot = try await .init(
            filePath: filePath,
            fileSystem: fileSystem,
            bytesDecoder: bytesDecoder,
            secretsSpecifier: secretsSpecifier
        )
    }
}

@available(Configuration 1.0, *)
extension JSONProvider: CustomStringConvertible {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public var description: String {
        "JSONProvider[\(_snapshot.values.count) values]"
    }
}

@available(Configuration 1.0, *)
extension JSONProvider: CustomDebugStringConvertible {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public var debugDescription: String {
        let prettyValues = _snapshot.values
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: ", ")
        return "JSONProvider[\(_snapshot.values.count) values: \(prettyValues)]"
    }
}

@available(Configuration 1.0, *)
extension JSONProvider: ConfigProvider {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public var providerName: String {
        _snapshot.providerName
    }

    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public func value(
        forKey key: AbsoluteConfigKey,
        type: ConfigType
    ) throws -> LookupResult {
        try _snapshot.value(forKey: key, type: type)
    }

    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public func fetchValue(
        forKey key: AbsoluteConfigKey,
        type: ConfigType
    ) async throws -> LookupResult {
        try value(forKey: key, type: type)
    }

    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public func watchSnapshot<Return>(
        updatesHandler: (ConfigUpdatesAsyncSequence<any ConfigSnapshotProtocol, Never>) async throws -> Return
    ) async throws -> Return {
        try await watchSnapshotFromSnapshot(updatesHandler: updatesHandler)
    }

    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public func watchValue<Return>(
        forKey key: AbsoluteConfigKey,
        type: ConfigType,
        updatesHandler: (
            ConfigUpdatesAsyncSequence<Result<LookupResult, any Error>, Never>
        ) async throws -> Return
    ) async throws -> Return {
        try await watchValueFromValue(forKey: key, type: type, updatesHandler: updatesHandler)
    }

    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public func snapshot() -> any ConfigSnapshotProtocol {
        _snapshot
    }
}

#endif
