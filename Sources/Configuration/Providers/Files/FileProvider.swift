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

public import SystemPackage

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// A configuration provider that reads from a file on disk using a configurable snapshot type.
///
/// `FileProvider` is a generic file-based configuration provider that works with different
/// file formats by using different snapshot types that conform to ``FileConfigSnapshot``.
/// This allows for a unified interface for reading JSON, YAML, or other structured configuration files.
///
/// ## Usage
///
/// Create a provider by specifying the snapshot type and file path:
///
/// ```swift
/// // Using with a JSON snapshot
/// let jsonProvider = try await FileProvider<JSONSnapshot>(
///     filePath: "/etc/config.json"
/// )
///
/// // Using with a YAML snapshot
/// let yamlProvider = try await FileProvider<YAMLSnapshot>(
///     filePath: "/etc/config.yaml"
/// )
/// ```
///
/// The provider reads the file once during initialization and creates an immutable snapshot
/// of the configuration values. For auto-reloading behavior, use ``ReloadingFileProvider``.
///
/// ## Configuration from a reader
///
/// You can also initialize the provider using a configuration reader that specifies
/// the file path through environment variables or other configuration sources:
///
/// ```swift
/// let envConfig = ConfigReader(provider: EnvironmentVariablesProvider())
/// let provider = try await FileProvider<JSONSnapshot>(config: envConfig)
/// ```
///
/// This expects a `filePath` key in the configuration that specifies the path to the file.
/// For a full list of configuration keys, check out ``FileProvider/init(snapshotType:parsingOptions:config:)``.
@available(Configuration 1.0, *)
public struct FileProvider<Snapshot: FileConfigSnapshot>: Sendable {

    /// A snapshot of the internal state.
    private let _snapshot: any ConfigSnapshot & CustomStringConvertible & CustomDebugStringConvertible

    /// Creates a file provider that reads from the specified file path.
    ///
    /// This initializer reads the file at the given path and creates a snapshot using the
    /// specified snapshot type. The file is read once during initialization.
    ///
    /// - Parameters:
    ///   - snapshotType: The type of snapshot to create from the file contents.
    ///   - parsingOptions: Options used by the snapshot to parse the file data.
    ///   - filePath: The path to the configuration file to read.
    ///   - allowMissing: A flag controlling how the provider handles a missing file.
    ///     - When `false` (the default), if the file is missing or malformed, throws an error.
    ///     - When `true`, if the file is missing, treats it as empty. Malformed files still throw an error.
    /// - Throws: If snapshot creation fails or if the file is malformed. Whether an error is thrown
    ///   when the file is missing is controlled by the `allowMissing` parameter.
    public init(
        snapshotType: Snapshot.Type = Snapshot.self,
        parsingOptions: Snapshot.ParsingOptions = .default,
        filePath: FilePath,
        allowMissing: Bool = false
    ) async throws {
        try await self.init(
            snapshotType: snapshotType,
            parsingOptions: parsingOptions,
            filePath: filePath,
            allowMissing: allowMissing,
            fileSystem: LocalCommonProviderFileSystem()
        )
    }

    /// Creates a file provider using a file path from a configuration reader.
    ///
    /// This initializer reads the file path from the provided configuration reader
    /// and creates a snapshot from that file.
    ///
    /// ## Configuration keys
    ///
    /// - `filePath` (string, required): The path to the configuration file to read.
    /// - `allowMissing` (bool, optional, default: false): A flag controlling how
    ///   the provider handles a missing file. When `false` (the default), if the file
    ///   is missing or malformed, throws an error. When `true`, if the file is missing,
    ///   treats it as empty. Malformed files still throw an error.
    ///
    /// - Parameters:
    ///   - snapshotType: The type of snapshot to create from the file contents.
    ///   - parsingOptions: Options used by the snapshot to parse the file data.
    ///   - config: A configuration reader that contains the required configuration keys.
    /// - Throws: If snapshot creation fails or if the file is malformed. Whether an error is thrown
    ///   when the file is missing is controlled by the `allowMissing` configuration value.
    public init(
        snapshotType: Snapshot.Type = Snapshot.self,
        parsingOptions: Snapshot.ParsingOptions = .default,
        config: ConfigReader
    ) async throws {
        try await self.init(
            snapshotType: snapshotType,
            parsingOptions: parsingOptions,
            filePath: config.requiredString(forKey: "filePath", as: FilePath.self),
            allowMissing: config.bool(forKey: "allowMissing", default: false)
        )
    }

    /// Creates a file provider using a file path from a configuration reader.
    ///
    /// This initializer reads the file path from the provided configuration reader
    /// and creates a snapshot from that file.
    ///
    /// ## Configuration keys
    ///
    /// - `filePath` (string, required): The path to the configuration file to read.
    /// - `allowMissing` (bool, optional, default: false): A flag controlling how
    ///   the provider handles a missing file. When `false` (the default), if the file
    ///   is missing or malformed, throws an error. When `true`, if the file is missing,
    ///   treats it as empty. Malformed files still throw an error.
    ///
    /// - Parameters:
    ///   - snapshotType: The type of snapshot to create from the file contents.
    ///   - parsingOptions: Options used by the snapshot to parse the file data.
    ///   - config: A configuration reader that contains the required configuration keys.
    ///   - fileSystem: The file system implementation to use for reading the file.
    /// - Throws: If snapshot creation fails or if the file is malformed. Whether an error is thrown
    ///   when the file is missing is controlled by the `allowMissing` configuration value.
    internal init(
        snapshotType: Snapshot.Type = Snapshot.self,
        parsingOptions: Snapshot.ParsingOptions = .default,
        config: ConfigReader,
        fileSystem: some CommonProviderFileSystem
    ) async throws {
        try await self.init(
            snapshotType: snapshotType,
            parsingOptions: parsingOptions,
            filePath: config.requiredString(forKey: "filePath", as: FilePath.self),
            allowMissing: config.bool(forKey: "allowMissing", default: false),
            fileSystem: fileSystem
        )
    }

    /// Creates a file provider.
    ///
    /// This internal initializer allows specifying a custom file system implementation,
    /// which is primarily used for testing and internal operations.
    ///
    /// - Parameters:
    ///   - snapshotType: The type of snapshot to create from the file contents.
    ///   - parsingOptions: Options used by the snapshot to parse the file data.
    ///   - filePath: The path to the configuration file to read.
    ///   - allowMissing: A flag controlling how the provider handles a missing file.
    ///     - When `false` (the default), if the file is missing or malformed, throws an error.
    ///     - When `true`, if the file is missing, treats it as empty. Malformed files still throw an error.
    ///   - fileSystem: The file system implementation to use for reading the file.
    /// - Throws: If the file cannot be read or if snapshot creation fails.
    internal init(
        snapshotType: Snapshot.Type = Snapshot.self,
        parsingOptions: Snapshot.ParsingOptions,
        filePath: FilePath,
        allowMissing: Bool,
        fileSystem: some CommonProviderFileSystem
    ) async throws {
        let fileContents = try await fileSystem.fileContents(atPath: filePath)
        let providerName = "FileProvider<\(Snapshot.self)>"
        /// Debug swift 6.2.3 compiler crashes if we shadow fileContents.
        /// See https://github.com/apple/swift-configuration/pull/151
        if fileContents != nil {
            self._snapshot = try snapshotType.init(
                data: fileContents!.bytes,
                providerName: providerName,
                parsingOptions: parsingOptions
            )
        } else if allowMissing {
            self._snapshot = EmptyFileConfigSnapshot(providerName: providerName)
        } else {
            throw FileSystemError.fileNotFound(path: filePath)
        }
    }
}

@available(Configuration 1.0, *)
extension FileProvider: CustomStringConvertible {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public var description: String {
        _snapshot.description
    }
}

@available(Configuration 1.0, *)
extension FileProvider: CustomDebugStringConvertible {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public var debugDescription: String {
        _snapshot.debugDescription
    }
}

@available(Configuration 1.0, *)
extension FileProvider: ConfigProvider {
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
    public func watchSnapshot<Return: ~Copyable>(
        updatesHandler: (_ updates: ConfigUpdatesAsyncSequence<any ConfigSnapshot, Never>) async throws -> Return
    ) async throws -> Return {
        try await watchSnapshotFromSnapshot(updatesHandler: updatesHandler)
    }

    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public func watchValue<Return: ~Copyable>(
        forKey key: AbsoluteConfigKey,
        type: ConfigType,
        updatesHandler: (
            _ updates: ConfigUpdatesAsyncSequence<Result<LookupResult, any Error>, Never>
        ) async throws -> Return
    ) async throws -> Return {
        try await watchValueFromValue(forKey: key, type: type, updatesHandler: updatesHandler)
    }

    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public func snapshot() -> any ConfigSnapshot {
        _snapshot
    }
}
