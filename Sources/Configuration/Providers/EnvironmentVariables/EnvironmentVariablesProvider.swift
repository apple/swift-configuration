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
public import SystemPackage
#if canImport(Darwin)
import Darwin
#elseif os(Windows)
import CRT
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Android)
import Android
#elseif canImport(Musl)
import Musl
#elseif canImport(WASILibc)
import WASILibc
#else
#error("Unsupported runtime")
#endif

/// A configuration provider that sources values from environment variables.
///
/// This provider reads configuration values from environment variables, supporting both
/// the current process environment and `.env` files. It automatically converts hierarchical
/// configuration keys into standard environment variable naming conventions and handles
/// type conversion for all supported configuration value types.
///
/// ## Key transformation
///
/// Configuration keys are transformed into environment variable names using these rules:
/// - Components are joined with underscores
/// - All characters are converted to uppercase
/// - CamelCase is detected and word boundaries are marked with underscores
/// - Non-alphanumeric characters are replaced with underscores
///
/// For example: `http.serverTimeout` becomes `HTTP_SERVER_TIMEOUT`
///
/// ## Supported data types
///
/// The provider supports all standard configuration types:
/// - Strings, integers, doubles, and booleans
/// - Arrays of strings, integers, doubles, and booleans (comma-separated by default)
/// - Byte arrays (base64-encoded by default)
/// - Arrays of byte chunks
///
/// ## Secret handling
///
/// Environment variables can be marked as secrets using a ``SecretsSpecifier``.
/// Secret values are automatically redacted in debug output and logging.
///
/// > Important: This provider performs case-insensitive lookup of environment variable names.
///
/// ## Usage
///
/// ### Reading environment variables in the current process
///
/// ```swift
/// // Assuming the environment contains the following variables:
/// // HTTP_CLIENT_USER_AGENT=Config/1.0 (Test)
/// // HTTP_CLIENT_TIMEOUT=15.0
/// // HTTP_SECRET=s3cret
/// // HTTP_VERSION=2
/// // ENABLED=true
///
/// let provider = EnvironmentVariablesProvider(
///     secretsSpecifier: .specific(["HTTP_SECRET"])
/// )
/// // Prints all values, redacts "HTTP_SECRET" automatically.
/// print(provider)
/// let config = ConfigReader(provider: provider)
/// let isEnabled = config.bool(forKey: "enabled", default: false)
/// let userAgent = config.string(forKey: "http.client.user-agent", default: "unspecified")
/// // ...
/// ```
///
/// ### Reading environment variables from a `.env`-style file
///
/// ```swift
/// // Assuming the local file system has a file called `.env` in the current working directory
/// // with the following contents:
/// //
/// //    HTTP_CLIENT_USER_AGENT=Config/1.0 (Test)
/// //    HTTP_CLIENT_TIMEOUT=15.0
/// //    HTTP_SECRET=s3cret
/// //    HTTP_VERSION=2
/// //    ENABLED=true
///
/// let provider = try await EnvironmentVariablesProvider(
///     environmentFilePath: ".env",
///     secretsSpecifier: .specific(["HTTP_SECRET"])
/// )
/// // Prints all values, redacts "HTTP_SECRET" automatically.
/// print(provider)
/// let config = ConfigReader(provider: provider)
/// let isEnabled = config.bool(forKey: "enabled", default: false)
/// let userAgent = config.string(forKey: "http.client.user-agent", default: "unspecified")
/// // ...
/// ```
///
/// ### Config context
///
/// The environment variables provider ignores the context passed in ``AbsoluteConfigKey/context``.
@available(Configuration 1.0, *)
public struct EnvironmentVariablesProvider: Sendable {

    /// An environment variable value with a flag of whether it's secret.
    struct EnvironmentValue: Sendable {

        /// The string value of the environment variable.
        var stringValue: String

        /// Whether the value is secret.
        var isSecret: Bool
    }

    /// The snapshot of the internal state of the provider.
    struct Snapshot: Sendable {
        /// The name of the provider.
        let providerName: String = "EnvironmentVariablesProvider"

        /// The stored environment variables.
        var environmentVariables: [String: EnvironmentValue]

        /// A decoder of bytes from a string.
        var bytesDecoder: any ConfigBytesFromStringDecoder

        /// A decoder of arrays from a string.
        var arrayDecoder: EnvironmentValueArrayDecoder

        /// A decoder of bool values from a string.
        static func decodeBool(from string: String) -> Bool? {
            switch string.lowercased() {
            case "true", "yes", "1": true
            case "false", "no", "0": false
            default: nil
            }
        }
    }

    /// The underlying snapshot of the provider.
    private let _snapshot: Snapshot

    /// Creates a new provider that reads from the current process environment.
    ///
    /// This initializer creates a provider that sources configuration values from
    /// the environment variables of the current process.
    ///
    /// ```swift
    /// // Basic usage
    /// let provider = EnvironmentVariablesProvider()
    ///
    /// // With secret handling
    /// let provider = EnvironmentVariablesProvider(
    ///     secretsSpecifier: .specific(["API_KEY", "DATABASE_PASSWORD"])
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - secretsSpecifier: Specifies which environment variables should be treated as secrets.
    ///   - bytesDecoder: The decoder used for converting string values to byte arrays.
    ///   - arraySeparator: The character used to separate elements in array values.
    public init(
        secretsSpecifier: SecretsSpecifier<String, String> = .none,
        bytesDecoder: some ConfigBytesFromStringDecoder = .base64,
        arraySeparator: Character = ","
    ) {
        self.init(
            environmentVariables: ProcessInfo.processInfo.environment,
            secretsSpecifier: secretsSpecifier,
            bytesDecoder: bytesDecoder,
            arraySeparator: arraySeparator
        )
    }

    /// Creates a new provider from a custom dictionary of environment variables.
    ///
    /// This initializer allows you to provide a custom set of environment variables,
    /// which is useful for testing or when you want to override specific values.
    ///
    /// ```swift
    /// let customEnvironment = [
    ///     "DATABASE_HOST": "localhost",
    ///     "DATABASE_PORT": "5432",
    ///     "API_KEY": "secret-key"
    /// ]
    /// let provider = EnvironmentVariablesProvider(
    ///     environmentVariables: customEnvironment,
    ///     secretsSpecifier: .specific(["API_KEY"])
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - environmentVariables: A dictionary of environment variable names and values.
    ///   - secretsSpecifier: Specifies which environment variables should be treated as secrets.
    ///   - bytesDecoder: The decoder used for converting string values to byte arrays.
    ///   - arraySeparator: The character used to separate elements in array values.
    public init(
        environmentVariables: [String: String],
        secretsSpecifier: SecretsSpecifier<String, String> = .none,
        bytesDecoder: some ConfigBytesFromStringDecoder = .base64,
        arraySeparator: Character = ","
    ) {
        let tuples: [(String, EnvironmentValue)] = environmentVariables.map { key, value in
            (
                key,
                EnvironmentValue(
                    stringValue: value,
                    isSecret: secretsSpecifier.isSecret(key: key, value: value)
                )
            )
        }
        self._snapshot = .init(
            environmentVariables: Dictionary(uniqueKeysWithValues: tuples),
            bytesDecoder: bytesDecoder,
            arrayDecoder: EnvironmentValueArrayDecoder(separator: arraySeparator)
        )
    }

    /// Creates a new provider that reads from an environment file.
    ///
    /// This initializer loads environment variables from an `.env` file at the specified path.
    /// The file should contain key-value pairs in the format `KEY=value`, one per line.
    /// Comments (lines starting with `#`) and empty lines are ignored.
    ///
    /// ```swift
    /// // Load from a .env file
    /// let provider = try await EnvironmentVariablesProvider(
    ///     environmentFilePath: ".env",
    ///     allowMissing: true,
    ///     secretsSpecifier: .specific(["API_KEY"])
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - environmentFilePath: The file system path to the environment file to load.
    ///   - allowMissing: A flag controlling how the provider handles a missing file.
    ///     - When `false` (the default), if the file is missing or malformed, throws an error.
    ///     - When `true`, if the file is missing, treats it as empty. Malformed files still throw an error.
    ///   - secretsSpecifier: Specifies which environment variables should be treated as secrets.
    ///   - bytesDecoder: The decoder used for converting string values to byte arrays.
    ///   - arraySeparator: The character used to separate elements in array values.
    /// - Throws: If the file is malformed, or if missing when allowMissing is `false`.
    public init(
        environmentFilePath: FilePath,
        allowMissing: Bool = false,
        secretsSpecifier: SecretsSpecifier<String, String> = .none,
        bytesDecoder: some ConfigBytesFromStringDecoder = .base64,
        arraySeparator: Character = ","
    ) async throws {
        try await self.init(
            environmentFilePath: environmentFilePath,
            allowMissing: allowMissing,
            fileSystem: LocalCommonProviderFileSystem(),
            secretsSpecifier: secretsSpecifier,
            bytesDecoder: bytesDecoder,
            arraySeparator: arraySeparator
        )
    }

    /// Creates a new provider that reads from an environment file.
    /// - Parameters:
    ///   - environmentFilePath: The file system path to the environment file to load.
    ///   - allowMissing: A flag controlling how the provider handles a missing file.
    ///     - When `false` (the default), if the file is missing or malformed, throws an error.
    ///     - When `true`, if the file is missing, treats it as empty. Malformed files still throw an error.
    ///   - fileSystem: The file system implementation to use.
    ///   - secretsSpecifier: Specifies which environment variables should be treated as secrets.
    ///   - bytesDecoder: The decoder used for converting string values to byte arrays.
    ///   - arraySeparator: The character used to separate elements in array values.
    /// - Throws: If the file is malformed, or if missing when allowMissing is `false`.
    internal init(
        environmentFilePath: FilePath,
        allowMissing: Bool,
        fileSystem: some CommonProviderFileSystem,
        secretsSpecifier: SecretsSpecifier<String, String> = .none,
        bytesDecoder: some ConfigBytesFromStringDecoder = .base64,
        arraySeparator: Character = ","
    ) async throws {
        let loadedData = try await fileSystem.fileContents(atPath: environmentFilePath)
        let data: Data
        if let loadedData {
            data = loadedData
        } else if allowMissing {
            data = Data()
        } else {
            throw FileSystemError.fileNotFound(path: environmentFilePath)
        }
        let contents = String(decoding: data, as: UTF8.self)
        self.init(
            environmentVariables: EnvironmentFileParser.parsed(contents),
            secretsSpecifier: secretsSpecifier,
            bytesDecoder: bytesDecoder,
            arraySeparator: arraySeparator
        )
    }

    /// Returns the raw string value for a specific environment variable name.
    ///
    /// This method provides direct access to environment variable values by name,
    /// without any key transformation or type conversion. It's useful when you need
    /// to access environment variables that don't follow the standard configuration
    /// key naming conventions.
    ///
    /// ```swift
    /// let provider = EnvironmentVariablesProvider()
    /// let path = try provider.environmentValue(forName: "PATH")
    /// let home = try provider.environmentValue(forName: "HOME")
    /// ```
    ///
    /// - Parameter name: The exact name of the environment variable to retrieve.
    /// - Returns: The string value of the environment variable, or nil if not found.
    /// - Throws: Errors accessing environment variable data.
    public func environmentValue(forName name: String) throws -> String? {
        _snapshot.environmentVariables[name]?.stringValue
    }
}

/// A decoder of environment variable arrays.
///
/// Parses a string by splitting by the specified character and trimming the components.
@available(Configuration 1.0, *)
internal struct EnvironmentValueArrayDecoder {

    /// The separator used to split the string into an array.
    var separator: Character

    /// Decodes an array of environment values.
    /// - Parameter string: The source string to parse.
    /// - Returns: The parsed array.
    func decode(_ string: String) -> [String] {
        string.split(separator: separator).map { $0.trimmed() }
    }
}

@available(Configuration 1.0, *)
extension EnvironmentVariablesProvider: CustomStringConvertible {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public var description: String {
        "EnvironmentVariablesProvider[\(_snapshot.environmentVariables.count) values]"
    }
}

@available(Configuration 1.0, *)
extension EnvironmentVariablesProvider: CustomDebugStringConvertible {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public var debugDescription: String {
        let prettyValues = _snapshot.environmentVariables
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value.isSecret ? "<REDACTED>" : "\($0.value.stringValue)")" }
            .joined(separator: ", ")
        return "EnvironmentVariablesProvider[\(_snapshot.environmentVariables.count) values: \(prettyValues)]"
    }
}

@available(Configuration 1.0, *)
extension EnvironmentVariablesProvider.Snapshot {
    /// Parses a config value from the provided raw string value.
    /// - Parameters:
    ///   - name: The name of the config value.
    ///   - stringValue: The string value to parse.
    ///   - isSecret: Whether the value is secret.
    ///   - type: The config type.
    /// - Returns: The parsed config value.
    /// - Throws: If the value cannot be parsed.
    func parseValue(
        name: String,
        stringValue: String,
        isSecret: Bool,
        type: ConfigType
    ) throws -> ConfigValue {
        func throwMismatch() throws -> Never {
            throw ConfigError.configValueNotConvertible(name: name, type: type)
        }
        let content: ConfigContent
        switch type {
        case .string:
            content = .string(stringValue)
        case .int:
            guard let intValue = Int(stringValue) else {
                try throwMismatch()
            }
            content = .int(intValue)
        case .double:
            guard let doubleValue = Double(stringValue) else {
                try throwMismatch()
            }
            content = .double(doubleValue)
        case .bool:
            guard let boolValue = Self.decodeBool(from: stringValue) else {
                try throwMismatch()
            }
            content = .bool(boolValue)
        case .bytes:
            guard let bytesValue = bytesDecoder.decode(stringValue) else {
                try throwMismatch()
            }
            content = .bytes(bytesValue)
        case .stringArray:
            let arrayValue = arrayDecoder.decode(stringValue)
            content = .stringArray(arrayValue)
        case .intArray:
            let arrayValue = arrayDecoder.decode(stringValue)
            let intArray = try arrayValue.map { stringValue in
                guard let intValue = Int(stringValue) else {
                    try throwMismatch()
                }
                return intValue
            }
            content = .intArray(intArray)
        case .doubleArray:
            let arrayValue = arrayDecoder.decode(stringValue)
            let doubleArray = try arrayValue.map { stringValue in
                guard let doubleValue = Double(stringValue) else {
                    try throwMismatch()
                }
                return doubleValue
            }
            content = .doubleArray(doubleArray)
        case .boolArray:
            let arrayValue = arrayDecoder.decode(stringValue)
            let boolArray = try arrayValue.map { stringValue in
                guard let boolValue = Self.decodeBool(from: stringValue) else {
                    try throwMismatch()
                }
                return boolValue
            }
            content = .boolArray(boolArray)
        case .byteChunkArray:
            let arrayValue = arrayDecoder.decode(stringValue)
            let byteChunkArray = try arrayValue.map { stringValue in
                guard let bytesValue = bytesDecoder.decode(stringValue) else {
                    try throwMismatch()
                }
                return bytesValue
            }
            content = .byteChunkArray(byteChunkArray)
        }
        return .init(content, isSecret: isSecret)
    }
}

@available(Configuration 1.0, *)
extension EnvironmentVariablesProvider.Snapshot: ConfigSnapshot {
    func value(
        forKey key: AbsoluteConfigKey,
        type: ConfigType
    ) throws -> LookupResult {
        let encodedKey = EnvironmentKeyEncoder().encode(key)
        return try withConfigValueLookup(encodedKey: encodedKey) { () -> ConfigValue? in
            guard let envValue = environmentVariables[encodedKey] else {
                return nil
            }
            return try parseValue(
                name: encodedKey,
                stringValue: envValue.stringValue,
                isSecret: envValue.isSecret,
                type: type
            )
        }
    }
}

@available(Configuration 1.0, *)
extension EnvironmentVariablesProvider: ConfigProvider {
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
