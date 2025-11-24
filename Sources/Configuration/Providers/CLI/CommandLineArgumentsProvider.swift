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

#if CommandLineArgumentsSupport

/// A configuration provider that sources values from command-line arguments.
///
/// Reads configuration values from CLI arguments with type conversion and secrets handling.
/// Keys are encoded to CLI flags at lookup time.
///
/// ## Package traits
///
/// This type is guarded by the `CommandLineArgumentsSupport` package trait.
///
/// ## Key formats
///
/// - `--key value` - A key-value pair with separate arguments.
/// - `--key=value` - A key-value pair with an equals sign.
/// - `--flag` - A Boolean flag, treated as `true`.
/// - `--key val1 val2` - Multiple values (arrays).
///
/// Configuration keys are transformed to CLI flags: `["http", "serverTimeout"]` → `--http-server-timeout`.
///
/// ## Array handling
///
/// Arrays can be specified in multiple ways:
/// - **Space-separated**: `--tags swift configuration cli`
/// - **Repeated flags**: `--tags swift --tags configuration --tags cli`
/// - **Comma-separated**: `--tags swift,configuration,cli`
/// - **Mixed**: `--tags swift,configuration --tags cli`
///
/// All formats produce the same result when accessed as an array type.
///
/// ## Usage
///
/// ```swift
/// // CLI: program --debug --host localhost --ports 8080 8443
/// let provider = CommandLineArgumentsProvider()
/// let config = ConfigReader(provider: provider)
///
/// let isDebug = config.bool(forKey: "debug", default: false) // true
/// let host = config.string(forKey: "host", default: "0.0.0.0") // "localhost"
/// let ports = config.intArray(forKey: "ports", default: []) // [8080, 8443]
/// ```
///
/// ### With secrets
///
/// ```swift
/// let provider = CommandLineArgumentsProvider(
///     secretsSpecifier: .specific(["--api-key"])
/// )
/// ```
///
/// ### Custom arguments
///
/// ```swift
/// let provider = CommandLineArgumentsProvider(
///     arguments: ["program", "--verbose", "--timeout", "30"],
///     secretsSpecifier: .dynamic { key, _ in key.contains("--secret") }
/// )
/// ```
@available(Configuration 1.0, *)
public struct CommandLineArgumentsProvider {

    /// The underlying snapshot containing the parsed CLI arguments.
    private let _snapshot: CLISnapshot

    /// Creates a new CLI provider with the provided arguments.
    ///
    /// ```swift
    /// // Uses the current process's arguments.
    /// let provider = CommandLineArgumentsProvider()
    /// ```
    ///
    /// ```swift
    /// // Uses custom arguments.
    /// let provider = CommandLineArgumentsProvider(arguments: ["program", "--test", "--port", "8089"])
    /// ```
    ///
    /// - Parameters:
    ///   - arguments: The command-line arguments to parse.
    ///   - secretsSpecifier: Specifies which CLI arguments should be treated as secret.
    ///   - bytesDecoder: The decoder used for converting string values into bytes.
    public init(
        arguments: [String] = CommandLine.arguments,
        secretsSpecifier: SecretsSpecifier<String, String> = .none,
        bytesDecoder: some ConfigBytesFromStringDecoder = .base64
    ) {
        let parsedArguments = CLIArgumentParser().parse(arguments)
        self._snapshot = CLISnapshot(
            arguments: parsedArguments,
            bytesDecoder: bytesDecoder,
            secretsSpecifier: secretsSpecifier
        )
    }
}

@available(Configuration 1.0, *)
extension CommandLineArgumentsProvider: CustomStringConvertible {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public var description: String {
        "CommandLineArgumentsProvider[\(_snapshot.arguments.count) values]"
    }
}

@available(Configuration 1.0, *)
extension CommandLineArgumentsProvider: CustomDebugStringConvertible {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public var debugDescription: String {
        let prettyValues = _snapshot.arguments
            .sorted { $0.key < $1.key }
            .map { key, value in
                let isSecret = _snapshot.secretsSpecifier.isSecret(key: key, value: value.first ?? "")
                return "\(key)=\(isSecret ? "<REDACTED>" : "\(value.joined(separator: ","))")"
            }
            .joined(separator: ", ")
        return "CommandLineArgumentsProvider[\(_snapshot.arguments.count) values: \(prettyValues)]"
    }
}

@available(Configuration 1.0, *)
extension CommandLineArgumentsProvider: ConfigProvider {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public var providerName: String {
        _snapshot.providerName
    }

    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public func value(forKey key: AbsoluteConfigKey, type: ConfigType) throws -> LookupResult {
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

#endif
