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

#if YAMLSupport && ReloadingSupport

public import SystemPackage
public import ServiceLifecycle
public import Logging
public import Metrics
import Yams
import Synchronization
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// A configuration provider that loads values from a YAML file and automatically reloads them when the file changes.
///
/// This provider reads a YAML file from the file system and makes its values
/// available as configuration. Unlike ``YAMLProvider``, this provider continuously
/// monitors the file for changes and automatically reloads the configuration when
/// the file is modified.
///
/// The provider must be run as part of a [`ServiceGroup`](https://swiftpackageindex.com/swift-server/swift-service-lifecycle/documentation/servicelifecycle/servicegroup)
/// for the periodic reloading to work.
///
/// ## Package traits
///
/// This provider is guarded by the `YAMLSupport` and `ReloadingSupport` package traits.
///
/// ## File monitoring
///
/// The provider monitors the YAML file by checking its real path and modification timestamp at regular intervals
/// (default: 15 seconds). When a change is detected, the entire file is reloaded and parsed, and changed keys emit
/// a change event to active watchers.
///
/// ## Watching for changes
///
/// ```swift
/// let config = ConfigReader(provider: provider)
///
/// // Watch for changes to specific values
/// try await config.watchString(forKey: "database.host") { updates in
///     for await host in updates {
///         print("Database host updated: \(host)")
///     }
/// }
/// ```
///
/// ## Similarities to YAMLProvider
///
/// Check out ``YAMLProvider`` to learn more about using YAML for configuration. ``ReloadingYAMLProvider`` is
/// a reloading variant of ``YAMLProvider`` that otherwise follows the same behavior for handling secrets,
/// key and context mapping, and so on.
@available(Configuration 1.0, *)
public final class ReloadingYAMLProvider: Sendable {

    /// The core implementation that handles all reloading logic.
    private let core: ReloadingFileProviderCore<YAMLProviderSnapshot>

    /// Creates a new reloading YAML provider by loading the specified file.
    ///
    /// This initializer loads and parses the YAML file during initialization and
    /// sets up the monitoring infrastructure. The file must contain a valid YAML
    /// mapping at the root level.
    ///
    /// ```swift
    /// // Load configuration from a YAML file with custom settings
    /// let provider = try await ReloadingYAMLProvider(
    ///     filePath: "/etc/app-config.yaml",
    ///     pollInterval: .seconds(5),
    ///     secretsSpecifier: .keyBased { key in
    ///         key.contains("password") || key.contains("secret")
    ///     }
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - filePath: The file system path to the YAML configuration file.
    ///   - pollInterval: The interval between file modification checks. Defaults to 15 seconds.
    ///   - bytesDecoder: The decoder used to convert string values to byte arrays.
    ///   - secretsSpecifier: Specifies which configuration values should be treated as secrets.
    ///   - logger: The logger instance to use, or nil to create a default one.
    ///   - metrics: The metrics factory to use, or nil to use a no-op implementation.
    /// - Throws: If the file cannot be read or parsed, or if the YAML structure is invalid.
    public convenience init(
        filePath: FilePath,
        pollInterval: Duration = .seconds(15),
        bytesDecoder: some ConfigBytesFromStringDecoder = .base64,
        secretsSpecifier: SecretsSpecifier<String, Void> = .none,
        logger: Logger? = nil,
        metrics: (any MetricsFactory)? = nil
    ) async throws {
        try await self.init(
            filePath: filePath,
            pollInterval: pollInterval,
            bytesDecoder: bytesDecoder,
            secretsSpecifier: secretsSpecifier,
            fileSystem: LocalCommonProviderFileSystem(),
            logger: logger,
            metrics: metrics
        )
    }

    /// Creates a new provider.
    /// - Parameters:
    ///   - filePath: The path of the YAML file.
    ///   - pollInterval: The interval between file modification checks.
    ///   - bytesDecoder: A decoder of bytes from a string.
    ///   - secretsSpecifier: A secrets specifier in case some of the values should be treated as secret.
    ///   - fileSystem: The underlying file system.
    ///   - logger: The logger instance to use, or nil to create a default one.
    ///   - metrics: The metrics factory to use, or nil to use a no-op implementation.
    /// - Throws: If the file cannot be read or parsed, or if the YAML structure is invalid.
    internal init(
        filePath: FilePath,
        pollInterval: Duration,
        bytesDecoder: some ConfigBytesFromStringDecoder,
        secretsSpecifier: SecretsSpecifier<String, Void>,
        fileSystem: some CommonProviderFileSystem,
        logger: Logger?,
        metrics: (any MetricsFactory)?
    ) async throws {
        self.core = try await ReloadingFileProviderCore(
            filePath: filePath,
            pollInterval: pollInterval,
            providerName: "ReloadingYAMLProvider",
            fileSystem: fileSystem,
            logger: logger,
            metrics: metrics,
            createSnapshot: { data in
                // Parse YAML and create snapshot using existing logic
                let fileContents = String(decoding: data, as: UTF8.self)
                guard let mapping = try Yams.Parser(yaml: fileContents).singleRoot()?.mapping else {
                    throw YAMLProviderSnapshot.YAMLConfigError.topLevelYAMLValueIsNotMapping(filePath)
                }
                let values = try parseValues(
                    mapping,
                    keyEncoder: SeparatorKeyEncoder.dotSeparated,
                    secretsSpecifier: secretsSpecifier
                )
                return YAMLProviderSnapshot(
                    bytesDecoder: bytesDecoder,
                    values: values
                )
            }
        )
    }

    /// Creates a new reloading YAML provider using a file path from configuration.
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
    /// let yamlProvider = try await ReloadingYAMLProvider(
    ///     config: config.scoped(to: "yaml")
    /// )
    /// ```
    ///
    /// ## Required configuration keys
    ///
    /// - `filePath` (string): The file path to the YAML configuration file.
    /// - `pollIntervalSeconds` (int, optional, default: `15`): The interval at which the provider checks the
    ///   file's last modified timestamp.
    ///
    /// - Parameters:
    ///   - config: The configuration reader containing the file path.
    ///   - bytesDecoder: The decoder used to convert string values to byte arrays.
    ///   - secretsSpecifier: Specifies which configuration values should be treated as secrets.
    ///   - logger: The logger instance to use, or nil to create a default one.
    ///   - metrics: The metrics factory to use, or nil to use a no-op implementation.
    /// - Throws: If the file path is missing, or if the file cannot be read or parsed.
    public convenience init(
        config: ConfigReader,
        bytesDecoder: some ConfigBytesFromStringDecoder = .base64,
        secretsSpecifier: SecretsSpecifier<String, Void> = .none,
        logger: Logger? = nil,
        metrics: (any MetricsFactory)? = nil
    ) async throws {
        try await self.init(
            filePath: config.requiredString(forKey: "filePath", as: FilePath.self),
            pollInterval: .seconds(config.int(forKey: "pollIntervalSeconds", default: 15)),
            bytesDecoder: bytesDecoder,
            secretsSpecifier: secretsSpecifier,
            fileSystem: LocalCommonProviderFileSystem(),
            logger: logger,
            metrics: metrics
        )
    }
}

@available(Configuration 1.0, *)
extension ReloadingYAMLProvider: CustomStringConvertible {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public var description: String {
        let snapshot = core.snapshot() as! YAMLProviderSnapshot
        return snapshot.values.withLock { values in
            "ReloadingYAMLProvider[\(values.count) values]"
        }
    }
}

@available(Configuration 1.0, *)
extension ReloadingYAMLProvider: CustomDebugStringConvertible {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public var debugDescription: String {
        let snapshot = core.snapshot() as! YAMLProviderSnapshot
        return snapshot.values.withLock { values in
            let prettyValues =
                values
                .sorted { $0.key < $1.key }
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: ", ")
            return "ReloadingYAMLProvider[\(values.count) values: \(prettyValues)]"
        }
    }
}

@available(Configuration 1.0, *)
extension ReloadingYAMLProvider: ConfigProvider {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public var providerName: String {
        core.providerName
    }

    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public func value(forKey key: AbsoluteConfigKey, type: ConfigType) throws -> LookupResult {
        try core.value(forKey: key, type: type)
    }

    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public func fetchValue(forKey key: AbsoluteConfigKey, type: ConfigType) async throws -> LookupResult {
        try await core.fetchValue(forKey: key, type: type)
    }

    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public func watchValue<Return>(
        forKey key: AbsoluteConfigKey,
        type: ConfigType,
        updatesHandler: (ConfigUpdatesAsyncSequence<Result<LookupResult, any Error>, Never>) async throws -> Return
    ) async throws -> Return {
        try await core.watchValue(forKey: key, type: type, updatesHandler: updatesHandler)
    }

    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public func snapshot() -> any ConfigSnapshotProtocol {
        core.snapshot()
    }

    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public func watchSnapshot<Return>(
        updatesHandler: (ConfigUpdatesAsyncSequence<any ConfigSnapshotProtocol, Never>) async throws -> Return
    ) async throws -> Return {
        try await core.watchSnapshot(updatesHandler: updatesHandler)
    }
}

@available(Configuration 1.0, *)
extension ReloadingYAMLProvider: Service {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public func run() async throws {
        try await core.run()
    }
}

#endif
