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

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// An immutable snapshot of CLI arguments.
///
/// Converts parsed CLI arguments into a dictionary structure optimized for key-based lookups,
/// with type conversion performed at lookup time based on the requested type.
///
/// ## Value interpretation
///
/// - **Empty array**: Treated as a boolean `true` (flag was present).
/// - **Single value**: Treated as a string value.
/// - **Multiple values**: Treated as a string array.
///
/// ```swift
/// // CLI: --debug
/// snapshot.value(forKey: debugKey, type: .bool) // -> true
///
/// // CLI: --port 8080
/// snapshot.value(forKey: portKey, type: .int) // -> 8080
/// snapshot.value(forKey: portKey, type: .string) // -> "8080"
///
/// // CLI: --hosts server1 server2 server3
/// snapshot.value(forKey: hostsKey, type: .stringArray) // -> ["server1", "server2", "server3"]
/// ```
@available(Configuration 1.0, *)
internal struct CLISnapshot {

    /// The name of the provider that created this snapshot.
    let providerName: String = "CommandLineArgumentsProvider"

    /// The key encoder.
    let keyEncoder: CLIKeyEncoder = .init()

    /// The parsed CLI arguments stored as a dictionary for fast lookup.
    ///
    /// Keys are CLI flag names (including `--` prefix) and values are arrays
    /// of string arguments. Empty arrays indicate boolean flags.
    var arguments: [String: [String]]

    /// A decoder of bytes from a string.
    var bytesDecoder: any ConfigBytesFromStringDecoder

    /// The secrets specifier for determining which arguments are secret.
    var secretsSpecifier: SecretsSpecifier<String, String>

    /// Converts string values to the requested configuration type.
    ///
    /// - Parameters:
    ///   - values: The string values from CLI arguments.
    ///   - type: The requested configuration type.
    ///   - encodedKey: The encoded key name for error reporting.
    /// - Returns: A typed configuration value, or nil if conversion fails.
    /// - Throws: If the provided values cannot be converted to the specified type.
    private func convertValues(
        _ values: [String],
        to type: ConfigType,
        encodedKey: String
    ) throws -> ConfigValue? {
        // Determine if this value should be marked as secret.
        // For CLI, we use the encoded key and the first value (or empty string for flags).
        let firstValue = values.first ?? ""
        let isSecret = secretsSpecifier.isSecret(key: encodedKey, value: firstValue)
        switch type {
        case .bool:
            // Empty array means flag was present (true), single "false" means false
            if values.isEmpty {
                return ConfigValue(.bool(true), isSecret: isSecret)
            } else if values.count == 1 {
                guard let boolValue = Bool(values[0]) else {
                    throw ConfigError.configValueNotConvertible(name: encodedKey, type: type)
                }
                return ConfigValue(.bool(boolValue), isSecret: isSecret)
            } else {
                throw ConfigError.configValueNotConvertible(name: encodedKey, type: type)
            }
        case .string:
            guard values.count == 1 else {
                throw ConfigError.configValueNotConvertible(name: encodedKey, type: type)
            }
            return ConfigValue(.string(values[0]), isSecret: isSecret)
        case .int:
            guard values.count == 1, let intValue = Int(values[0]) else {
                throw ConfigError.configValueNotConvertible(name: encodedKey, type: type)
            }
            return ConfigValue(.int(intValue), isSecret: isSecret)
        case .double:
            guard values.count == 1, let doubleValue = Double(values[0]) else {
                throw ConfigError.configValueNotConvertible(name: encodedKey, type: type)
            }
            return ConfigValue(.double(doubleValue), isSecret: isSecret)
        case .stringArray:
            return ConfigValue(.stringArray(values), isSecret: isSecret)
        case .intArray:
            let intValues = try values.map { value in
                guard let intValue = Int(value) else {
                    throw ConfigError.configValueNotConvertible(name: encodedKey, type: type)
                }
                return intValue
            }
            return ConfigValue(.intArray(intValues), isSecret: isSecret)
        case .doubleArray:
            let doubleValues = try values.map { value in
                guard let doubleValue = Double(value) else {
                    throw ConfigError.configValueNotConvertible(name: encodedKey, type: type)
                }
                return doubleValue
            }
            return ConfigValue(.doubleArray(doubleValues), isSecret: isSecret)
        case .boolArray:
            let boolValues = try values.map { value in
                guard let boolValue = Bool(value) else {
                    throw ConfigError.configValueNotConvertible(name: encodedKey, type: type)
                }
                return boolValue
            }
            return ConfigValue(.boolArray(boolValues), isSecret: isSecret)
        case .bytes:
            guard values.count == 1 else {
                throw ConfigError.configValueNotConvertible(name: encodedKey, type: type)
            }
            guard let bytes = bytesDecoder.decode(values[0]) else {
                throw ConfigError.configValueNotConvertible(name: encodedKey, type: type)
            }
            return ConfigValue(.bytes(bytes), isSecret: isSecret)
        case .byteChunkArray:
            let byteChunks = try values.map { value in
                guard let bytes = bytesDecoder.decode(value) else {
                    throw ConfigError.configValueNotConvertible(name: encodedKey, type: type)
                }
                return bytes
            }
            return ConfigValue(.byteChunkArray(byteChunks), isSecret: isSecret)
        }
    }
}

@available(Configuration 1.0, *)
extension CLISnapshot: ConfigSnapshotProtocol {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    func value(forKey key: AbsoluteConfigKey, type: ConfigType) throws -> LookupResult {
        let encodedKey = keyEncoder.encode(key)
        return try withConfigValueLookup(encodedKey: encodedKey) {
            guard let values = arguments[encodedKey] else {
                return nil
            }
            return try convertValues(values, to: type, encodedKey: encodedKey)
        }
    }
}

#endif
