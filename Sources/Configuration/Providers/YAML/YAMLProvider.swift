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

#if YAMLSupport

public import SystemPackage
import Yams
import Synchronization
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// A configuration provider that loads values from YAML files.
///
/// This provider reads YAML files from the file system and makes their values
/// available as configuration. The YAML structure is flattened using dot notation,
/// allowing nested mappings to be accessed with hierarchical keys.
///
/// The provider loads the YAML file once during initialization and never reloads
/// it, making it a constant provider suitable for configuration that doesn't
/// change during application runtime.
///
/// > Tip: Do you need to watch the YAML files on disk for changes, and reload them automatically? Check out ``ReloadingYAMLProvider``.
///
/// ## Package traits
///
/// This provider is guarded by the `YAMLSupport` package trait.
///
/// ## Supported YAML types
///
/// The provider supports these YAML value types:
/// - **Scalars**: Strings, integers, doubles, and booleans
/// - **Sequences**: Homogeneous arrays of scalars
/// - **Mappings**: Nested objects that are flattened using dot notation
/// - **null**: Ignored (no configuration value is created)
///
/// ## Key flattening
///
/// Nested YAML mappings are flattened into dot-separated keys:
///
/// ```yaml
/// database:
///   host: localhost
///   port: 5432
/// features:
///   enabled: true
/// ```
///
/// Becomes accessible as:
/// - `database.host` → `"localhost"`
/// - `database.port` → `5432`
/// - `features.enabled` → `true`
///
/// ## Secret handling
///
/// The provider supports marking values as secret using a ``SecretsSpecifier``.
/// Secret values are automatically redacted in logs and debug output.
///
/// ## Usage
///
/// ```swift
/// // Load from a YAML file
/// let provider = try await YAMLProvider(filePath: "/etc/config.yaml")
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
public struct YAMLProvider: Sendable {

    /// A snapshot of the internal state.
    private let _snapshot: YAMLProviderSnapshot

    /// Creates a new YAML provider by loading the specified file.
    ///
    /// This initializer loads and parses the YAML file during initialization.
    /// The file must contain a valid YAML mapping at the root level.
    ///
    /// ```swift
    /// // Load configuration from a YAML file
    /// let provider = try await YAMLProvider(
    ///     filePath: "/etc/app-config.yaml",
    ///     secretsSpecifier: .keyBased { key in
    ///         key.contains("password") || key.contains("secret")
    ///     }
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - filePath: The file system path to the YAML configuration file.
    ///   - bytesDecoder: The decoder used to convert string values to byte arrays.
    ///   - secretsSpecifier: Specifies which configuration values should be treated as secrets.
    /// - Throws: If the file cannot be read or parsed, or if the YAML structure is invalid.
    public init(
        filePath: FilePath,
        bytesDecoder: some ConfigBytesFromStringDecoder = .base64,
        secretsSpecifier: SecretsSpecifier<String, Void> = .none
    ) async throws {
        try await self.init(
            filePath: filePath,
            fileSystem: LocalCommonProviderFileSystem(),
            bytesDecoder: bytesDecoder,
            secretsSpecifier: secretsSpecifier
        )
    }

    /// Creates a new YAML provider using a file path from configuration.
    ///
    /// This convenience initializer reads the YAML file path from another
    /// configuration source, allowing the YAML provider to be configured
    /// through configuration itself.
    ///
    /// ```swift
    /// // Configure YAML provider through environment variables
    /// let envProvider = EnvironmentVariablesProvider()
    /// let config = ConfigReader(provider: envProvider)
    ///
    /// // YAML_FILE_PATH environment variable specifies the file
    /// let yamlProvider = try await YAMLProvider(
    ///     config: config.scoped(to: "yaml")
    /// )
    /// ```
    ///
    /// ## Required configuration keys
    ///
    /// - `filePath` (string): The file path to the YAML configuration file.
    ///
    /// - Parameters:
    ///   - config: The configuration reader containing the file path.
    ///   - bytesDecoder: The decoder used to convert string values to byte arrays.
    ///   - secretsSpecifier: Specifies which configuration values should be treated as secrets.
    /// - Throws: If the file path is missing, or if the file cannot be read or parsed.
    public init(
        config: ConfigReader,
        bytesDecoder: some ConfigBytesFromStringDecoder = .base64,
        secretsSpecifier: SecretsSpecifier<String, Void> = .none
    ) async throws {
        try await self.init(
            filePath: config.requiredString(forKey: "filePath", as: FilePath.self),
            bytesDecoder: bytesDecoder,
            secretsSpecifier: secretsSpecifier
        )
    }

    /// Creates a new provider.
    /// - Parameters:
    ///   - filePath: The path of the YAML file.
    ///   - fileSystem: The underlying file system.
    ///   - bytesDecoder: A decoder of bytes from a string.
    ///   - secretsSpecifier: A secrets specifier in case some of the values should be treated as secret.
    /// - Throws: If the file cannot be read or parsed, or if the YAML structure is invalid.
    internal init(
        filePath: FilePath,
        fileSystem: some CommonProviderFileSystem,
        bytesDecoder: some ConfigBytesFromStringDecoder = .base64,
        secretsSpecifier: SecretsSpecifier<String, Void> = .none
    ) async throws {
        self._snapshot = try await .init(
            filePath: filePath,
            fileSystem: fileSystem,
            bytesDecoder: bytesDecoder,
            secretsSpecifier: secretsSpecifier
        )
    }
}

extension YAMLProvider: CustomStringConvertible {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public var description: String {
        _snapshot.values.withLock { values in
            "YAMLProvider[\(values.count) values]"
        }
    }
}

extension YAMLProvider: CustomDebugStringConvertible {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public var debugDescription: String {
        _snapshot.values.withLock { values in
            let prettyValues =
                values
                .sorted { $0.key < $1.key }
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: ", ")
            return "YAMLProvider[\(values.count) values: \(prettyValues)]"
        }
    }
}

extension YAMLProvider: ConfigProvider {
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

    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public func watchSnapshot<Return>(
        updatesHandler: (ConfigUpdatesAsyncSequence<any ConfigSnapshotProtocol, Never>) async throws -> Return
    ) async throws -> Return {
        try await watchSnapshotFromSnapshot(updatesHandler: updatesHandler)
    }
}

#endif
