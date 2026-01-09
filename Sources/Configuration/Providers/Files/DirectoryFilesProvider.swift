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
public import FoundationEssentials
#else
public import Foundation
#endif
public import SystemPackage

/// A configuration provider that reads values from individual files in a directory.
///
/// This provider reads configuration values from a directory where each file represents
/// a single configuration key-value pair. The file name becomes the configuration key,
/// and the file contents become the value. This approach is commonly used by secret
/// management systems that mount secrets as individual files.
///
/// ## Key mapping
///
/// This provider transforms configuration keys into file names using these rules:
/// - Joins components with dashes.
/// - Replaces non-alphanumeric characters (except dashes) with underscores.
///
/// For example:
/// - `database.password` -> `database-password`
///
/// ## Value handling
///
/// The provider reads file contents as UTF-8 strings and converts them to the requested
/// type. For binary data (bytes type), it reads raw file contents directly without
/// string conversion. The provider always trims leading and trailing whitespace from string values.
///
/// ## Supported data types
///
/// The provider supports all standard configuration types:
/// - Strings (UTF-8 text files)
/// - Integers, doubles, and booleans (parsed from string contents)
/// - Arrays (using configurable separator, comma by default)
/// - Byte arrays (raw file contents)
///
/// ## Secret handling
///
/// By default, all values are marked as secrets for security. This is appropriate
/// since this provider is typically used for sensitive data mounted by secret
/// management systems.
///
/// ## Usage
///
/// ### Reading from a secrets directory
///
/// ```swift
/// // Assuming /run/secrets contains files:
/// // - database-password (contains: "secretpass123")
/// // - max-connections (contains: "100")
/// // - enable-cache (contains: "true")
///
/// let provider = try await DirectoryFilesProvider(
///     directoryPath: "/run/secrets"
/// )
///
/// let config = ConfigReader(provider: provider)
/// let dbPassword = config.string(forKey: "database.password")  // "secretpass123"
/// let maxConn = config.int(forKey: "max.connections", default: 50)  // 100
/// let cacheEnabled = config.bool(forKey: "enable.cache", default: false)  // true
/// ```
///
/// ### Reading binary data
///
/// ```swift
/// // For binary files like certificates or keys
/// let provider = try await DirectoryFilesProvider(
///     directoryPath: "/run/secrets"
/// )
///
/// let config = ConfigReader(provider: provider)
/// let certData = try config.requiredBytes(forKey: "tls.cert")  // Raw file bytes
/// ```
///
/// ### Custom array handling
///
/// ```swift
/// // If files contain comma-separated lists
/// let provider = try await DirectoryFilesProvider(
///     directoryPath: "/etc/config"
/// )
///
/// // File "allowed-hosts" contains: "host1.example.com,host2.example.com,host3.example.com"
/// let hosts = config.stringArray(forKey: "allowed.hosts", default: [])
/// // ["host1.example.com", "host2.example.com", "host3.example.com"]
/// ```
///
/// ## Configuration context
///
/// This provider ignores the context passed in ``AbsoluteConfigKey/context``.
/// All keys are resolved using only their component path.
@available(Configuration 1.0, *)
public struct DirectoryFilesProvider: Sendable {

    /// A file value with metadata.
    struct FileValue: Sendable {
        /// The raw data from the file.
        var data: Data

        /// Whether the value is secret.
        var isSecret: Bool
    }

    /// The snapshot of the internal state of the provider.
    ///
    /// This struct contains the immutable state of the provider at a point in time,
    /// including all loaded file values and configuration for processing them.
    struct Snapshot: Sendable {
        /// The name of the provider.
        let providerName: String = "DirectoryFilesProvider"

        /// The stored file values keyed by file name.
        var fileValues: [String: FileValue]

        /// A decoder of arrays from a string.
        var arrayDecoder: DirectoryFilesValueArrayDecoder

        /// The key encoder for converting config keys to file names.
        var keyEncoder: any ConfigKeyEncoder = .directoryFiles
    }

    /// The underlying snapshot of the provider.
    private let _snapshot: Snapshot

    /// Creates a new provider that reads files from a directory.
    ///
    /// This initializer scans the specified directory and loads all regular files
    /// as configuration values. Subdirectories are not traversed. Hidden files
    /// (starting with a dot) are skipped.
    ///
    /// ```swift
    /// // Load configuration from a directory
    /// let provider = try await DirectoryFilesProvider(
    ///     directoryPath: "/run/secrets"
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - directoryPath: The file system path to the directory containing configuration files.
    ///   - allowMissing: A flag controlling how the provider handles a missing directory.
    ///     - When `false`, if the directory is missing, throws an error.
    ///     - When `true`, if the directory is missing, treats it as empty.
    ///   - secretsSpecifier: Specifies which values should be treated as secrets.
    ///   - arraySeparator: The character used to separate elements in array values.
    /// - Throws: If the directory doesn't exist or is unreadable.
    public init(
        directoryPath: FilePath,
        allowMissing: Bool = false,
        secretsSpecifier: SecretsSpecifier<String, Data> = .all,
        arraySeparator: Character = ","
    ) async throws {
        try await self.init(
            directoryPath: directoryPath,
            allowMissing: allowMissing,
            fileSystem: LocalCommonProviderFileSystem(),
            secretsSpecifier: secretsSpecifier,
            arraySeparator: arraySeparator
        )
    }

    /// Creates a new provider that reads files from a directory using a custom file system.
    ///
    /// This internal initializer allows injecting a custom file system implementation,
    /// primarily used for testing with in-memory file systems.
    ///
    /// - Parameters:
    ///   - directoryPath: The file system path to the directory containing configuration files.
    ///   - allowMissing: A flag controlling how the provider handles a missing directory.
    ///     - When `false`, if the directory is missing, throws an error.
    ///     - When `true`, if the directory is missing, treats it as empty.
    ///   - fileSystem: The file system implementation to use.
    ///   - secretsSpecifier: Specifies which values should be treated as secrets. Defaults to `.all`.
    ///   - arraySeparator: The character used to separate elements in array values. Defaults to comma.
    /// - Throws: If the directory doesn't exist or is unreadable.
    internal init(
        directoryPath: FilePath,
        allowMissing: Bool,
        fileSystem: some CommonProviderFileSystem,
        secretsSpecifier: SecretsSpecifier<String, Data> = .all,
        arraySeparator: Character = ","
    ) async throws {
        let fileValues = try await Self.loadDirectory(
            at: directoryPath,
            allowMissing: allowMissing,
            fileSystem: fileSystem,
            secretsSpecifier: secretsSpecifier
        )
        self._snapshot = .init(
            fileValues: fileValues,
            arrayDecoder: DirectoryFilesValueArrayDecoder(separator: arraySeparator)
        )
    }

    /// Loads all files from a directory.
    ///
    /// This method scans a directory for regular files and loads their contents
    /// into memory, applying the secrets specifier to determine which values
    /// should be marked as secret.
    ///
    /// - Parameters:
    ///   - directoryPath: The path to the directory to load files from.
    ///   - allowMissing: A flag controlling how the provider handles a missing directory.
    ///     - When `false`, if the directory is missing, throws an error.
    ///     - When `true`, if the directory is missing, treats it as empty.
    ///   - fileSystem: The file system implementation to use.
    ///   - secretsSpecifier: Specifies which values should be treated as secrets.
    /// - Returns: A dictionary of file values keyed by file name.
    /// - Throws: If the directory doesn't exist or is unreadable, or any file is unreadable.
    private static func loadDirectory(
        at directoryPath: FilePath,
        allowMissing: Bool,
        fileSystem: some CommonProviderFileSystem,
        secretsSpecifier: SecretsSpecifier<String, Data>
    ) async throws -> [String: FileValue] {
        let loadedFileNames = try await fileSystem.listFileNames(atPath: directoryPath)
        let fileNames: [String]
        if let loadedFileNames {
            fileNames = loadedFileNames
        } else if allowMissing {
            fileNames = []
        } else {
            throw FileSystemError.directoryNotFound(path: directoryPath)
        }
        var fileValues: [String: FileValue] = [:]
        for fileName in fileNames {
            let filePath = directoryPath.appending(fileName)
            guard let data = try await fileSystem.fileContents(atPath: filePath) else {
                // File disappeared since the last call, that's okay as no individual
                // file in a DirectoryFilesProvider is required. Just skip it.
                continue
            }
            let isSecret = secretsSpecifier.isSecret(key: fileName, value: data)
            fileValues[fileName] = .init(data: data, isSecret: isSecret)
        }
        return fileValues
    }
}

/// A decoder of file content arrays.
///
/// Parses a string by splitting by the specified character and trimming the components.
@available(Configuration 1.0, *)
internal struct DirectoryFilesValueArrayDecoder {

    /// The separator used to split the string into an array.
    var separator: Character

    /// Decodes an array of values from a single file's contents.
    /// - Parameter string: The source string to parse.
    /// - Returns: The parsed array.
    func decode(_ string: String) -> [String] {
        string.split(separator: separator).map { $0.trimmed() }
    }
}

@available(Configuration 1.0, *)
extension DirectoryFilesProvider: CustomStringConvertible {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public var description: String {
        "DirectoryFilesProvider[\(_snapshot.fileValues.count) files]"
    }
}

@available(Configuration 1.0, *)
extension DirectoryFilesProvider: CustomDebugStringConvertible {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public var debugDescription: String {
        let prettyValues = _snapshot.fileValues
            .sorted { $0.key < $1.key }
            .map { key, value in
                let displayValue: String
                if value.isSecret {
                    displayValue = "<REDACTED>"
                } else {
                    let stringValue = String(decoding: value.data, as: UTF8.self)
                    displayValue = stringValue.trimmed()
                }
                return "\(key)=\(displayValue)"
            }
            .joined(separator: ", ")
        return "DirectoryFilesProvider[\(_snapshot.fileValues.count) files: \(prettyValues)]"
    }
}

@available(Configuration 1.0, *)
extension DirectoryFilesProvider.Snapshot {
    /// Parses a config value from the provided file value.
    /// - Parameters:
    ///   - name: The name of the config value (file name).
    ///   - fileValue: The file value to parse.
    ///   - type: The config type.
    /// - Returns: The parsed config value.
    /// - Throws: If the value cannot be parsed.
    func parseValue(
        name: String,
        fileValue: DirectoryFilesProvider.FileValue,
        type: ConfigType
    ) throws -> ConfigValue {
        func throwMismatch() throws -> Never {
            throw ConfigError.configValueNotConvertible(name: name, type: type)
        }
        func stringValue() -> String {
            String(decoding: fileValue.data, as: UTF8.self)
                .trimmed()
        }

        let content: ConfigContent
        switch type {
        case .string:
            content = .string(stringValue())
        case .int:
            guard let intValue = Int(stringValue()) else {
                try throwMismatch()
            }
            content = .int(intValue)
        case .double:
            guard let doubleValue = Double(stringValue()) else {
                try throwMismatch()
            }
            content = .double(doubleValue)
        case .bool:
            guard let boolValue = Bool(stringValue()) else {
                try throwMismatch()
            }
            content = .bool(boolValue)
        case .bytes:
            // For bytes, always use raw file data
            content = .bytes(Array(fileValue.data))
        case .stringArray:
            let arrayValue = arrayDecoder.decode(stringValue())
            content = .stringArray(arrayValue)
        case .intArray:
            let arrayValue = arrayDecoder.decode(stringValue())
            let intArray = try arrayValue.map { stringValue in
                guard let intValue = Int(stringValue) else {
                    try throwMismatch()
                }
                return intValue
            }
            content = .intArray(intArray)
        case .doubleArray:
            let arrayValue = arrayDecoder.decode(stringValue())
            let doubleArray = try arrayValue.map { stringValue in
                guard let doubleValue = Double(stringValue) else {
                    try throwMismatch()
                }
                return doubleValue
            }
            content = .doubleArray(doubleArray)
        case .boolArray:
            let arrayValue = arrayDecoder.decode(stringValue())
            let boolArray = try arrayValue.map { stringValue in
                guard let boolValue = Bool(stringValue) else {
                    try throwMismatch()
                }
                return boolValue
            }
            content = .boolArray(boolArray)
        case .byteChunkArray:
            // For byte chunk arrays, treat the whole file as a single element
            content = .byteChunkArray([Array(fileValue.data)])
        }
        return .init(content, isSecret: fileValue.isSecret)
    }
}

@available(Configuration 1.0, *)
extension DirectoryFilesProvider.Snapshot: ConfigSnapshot {
    func value(
        forKey key: AbsoluteConfigKey,
        type: ConfigType
    ) throws -> LookupResult {
        let fileName = keyEncoder.encode(key)
        return try withConfigValueLookup(encodedKey: fileName) { () -> ConfigValue? in
            guard let fileValue = fileValues[fileName] else {
                return nil
            }
            return try parseValue(
                name: fileName,
                fileValue: fileValue,
                type: type
            )
        }
    }
}

@available(Configuration 1.0, *)
extension DirectoryFilesProvider: ConfigProvider {
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
    public func watchValue<Return: ~Copyable>(
        forKey key: AbsoluteConfigKey,
        type: ConfigType,
        updatesHandler: (_ updates: ConfigUpdatesAsyncSequence<Result<LookupResult, any Error>, Never>) async throws ->
            Return
    ) async throws -> Return {
        try await watchValueFromValue(forKey: key, type: type, updatesHandler: updatesHandler)
    }

    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public func snapshot() -> any ConfigSnapshot {
        _snapshot
    }

    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public func watchSnapshot<Return: ~Copyable>(
        updatesHandler: (_ updates: ConfigUpdatesAsyncSequence<any ConfigSnapshot, Never>) async throws -> Return
    ) async throws -> Return {
        try await watchSnapshotFromSnapshot(updatesHandler: updatesHandler)
    }
}

/// A key encoder that converts configuration keys to safe file names.
///
/// This encoder transforms configuration keys into file names using these rules:
/// - Joins components with dashes.
/// - Replaces non-alphanumeric characters (except dashes) with underscores.
@available(Configuration 1.0, *)
internal struct DirectoryFileKeyEncoder {
    /// Creates a default directory key encoder that follows standard file naming conventions.
    public init() {}
}

@available(Configuration 1.0, *)
extension DirectoryFileKeyEncoder: ConfigKeyEncoder {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    func encode(_ key: AbsoluteConfigKey) -> String {
        key.components
            .map { component in
                component
                    .map { char in
                        // Allow alphanumeric characters and dashes
                        if char.isLetter || char.isNumber || char == "-" {
                            return String(char)
                        } else {
                            return "_"
                        }
                    }
                    .joined()
            }
            .joined(separator: "-")
    }
}

@available(Configuration 1.0, *)
extension ConfigKeyEncoder where Self == DirectoryFileKeyEncoder {
    /// An encoder that uses directory paths for hierarchical key encoder.
    ///
    /// This encoder transforms configuration keys into file names using these rules:
    /// - Joins components with dashes.
    /// - Replaces non-alphanumeric characters (except dashes) with underscores.
    ///
    /// - Returns: A new key encoder.
    static var directoryFiles: Self {
        DirectoryFileKeyEncoder()
    }
}
