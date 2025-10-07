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

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import Yams
import Synchronization
import SystemPackage

/// A snapshot of configuration values parsed from YAML data.
///
/// This class represents a point-in-time view of configuration values. It handles
/// the conversion from YAML types to configuration value types.
@available(Configuration 1.0, *)
final class YAMLProviderSnapshot: Sendable {
    /// The key encoder for YAML.
    private static let keyEncoder: SeparatorKeyEncoder = .dotSeparated

    /// A parsed YAML value compatible with the config system.
    enum YAMLValue: CustomStringConvertible {

        /// A scalar: a string, int, double, bool.
        case scalar(Yams.Node.Scalar)

        /// A sequence: an array.
        case sequence([Yams.Node.Scalar])

        var description: String {
            switch self {
            case .scalar(let scalar):
                return "\(scalar.string)"
            case .sequence(let sequence):
                return sequence.map(\.string).joined(separator: ",")
            }
        }
    }

    /// A wrapper of a YAML value with the information of whether it's secret.
    internal struct ValueWrapper: CustomStringConvertible {

        /// The underlying YAML value.
        var value: YAMLValue

        /// Whether it should be treated as secret and not logged in plain text.
        var isSecret: Bool

        var description: String {
            if isSecret {
                return "<REDACTED>"
            }
            return "\(value)"
        }
    }

    /// The internal YAML provider error type.
    internal enum YAMLConfigError: Error, CustomStringConvertible {

        /// The top level YAML value was not a mapping.
        case topLevelYAMLValueIsNotMapping(FilePath)

        /// A YAML key is not convertible to string.
        case keyNotConvertibleToString([String])

        /// The YAML primitive type is not supported.
        case unsupportedPrimitiveValue([String])

        /// Detected an array with a non-scalar type, which isn't supported.
        case nonScalarValueInArray([String], Int)

        /// Detected an array with a heterogeneous scalar type, which isn't supported.
        case unexpectedScalarValueInArray([String], Int)

        var description: String {
            switch self {
            case .topLevelYAMLValueIsNotMapping(let path):
                return "Top level YAML value is not a mapping. File: \(path)"
            case .keyNotConvertibleToString(let keyPath):
                return "YAML key is not convertible to string: \(keyPath.joined(separator: "."))"
            case .unsupportedPrimitiveValue(let keyPath):
                return "Unsupported primitive value at \(keyPath.joined(separator: "."))"
            case .nonScalarValueInArray(let keyPath, let index):
                return "Unexpected non-scalar value in array at \(keyPath.joined(separator: ".")) at index: \(index)."
            case .unexpectedScalarValueInArray(let keyPath, let index):
                return "Unexpected scalar value in array at \(keyPath.joined(separator: ".")) at index: \(index)."
            }
        }
    }

    /// A decoder of bytes from a string.
    let bytesDecoder: any ConfigBytesFromStringDecoder

    /// The underlying config values.
    ///
    /// Using a Mutex since the Yams types aren't Sendable.
    let values: Mutex<[String: ValueWrapper]>

    /// Creates a snapshot with pre-parsed values.
    ///
    /// - Parameters:
    ///   - bytesDecoder: The decoder for converting string values to bytes.
    ///   - values: The configuration values.
    init(bytesDecoder: some ConfigBytesFromStringDecoder, values: sending [String: ValueWrapper]) {
        self.bytesDecoder = bytesDecoder
        self.values = .init(values)
    }

    /// Creates a snapshot by parsing YAML data from a file.
    ///
    /// This initializer reads YAML data from the specified file, parses it using
    /// the Yams library, and converts the parsed values into the internal
    /// configuration format. The top-level YAML value must be a mapping.
    ///
    /// - Parameters:
    ///   - filePath: The path of the YAML file to read.
    ///   - fileSystem: The file system interface for reading the file.
    ///   - bytesDecoder: The decoder for converting string values to bytes.
    ///   - secretsSpecifier: The specifier for identifying secret values.
    /// - Throws: An error if the YAML root is not a mapping, or any error from
    ///   file reading or YAML parsing.
    convenience init(
        filePath: FilePath,
        fileSystem: some CommonProviderFileSystem,
        bytesDecoder: some ConfigBytesFromStringDecoder,
        secretsSpecifier: SecretsSpecifier<String, Void>
    ) async throws {
        let fileContents = try await fileSystem.fileContents(atPath: filePath)
        guard let mapping = try Yams.Parser(yaml: fileContents).singleRoot()?.mapping else {
            throw YAMLProviderSnapshot.YAMLConfigError.topLevelYAMLValueIsNotMapping(filePath)
        }
        let values = try parseValues(
            mapping,
            keyEncoder: Self.keyEncoder,
            secretsSpecifier: secretsSpecifier
        )
        self.init(
            bytesDecoder: bytesDecoder,
            values: values
        )
    }

    /// Parses config content from the provided YAML value.
    /// - Parameters:
    ///   - valueWrapper: The wrapped YAML value.
    ///   - key: The config key.
    ///   - type: The config type.
    /// - Returns: The parsed config value.
    /// - Throws: If the value cannot be parsed.
    private func parseValue(
        _ valueWrapper: ValueWrapper,
        key: AbsoluteConfigKey,
        type: ConfigType
    ) throws -> ConfigValue {
        func throwMismatch() throws -> Never {
            throw ConfigError.configValueNotConvertible(name: key.description, type: type)
        }
        func getTypedArray<Value>(_ value: YAMLValue, transform: (Yams.Node.Scalar) -> Value?) throws -> [Value] {
            guard case .sequence(let array) = value else {
                try throwMismatch()
            }
            return try array.enumerated()
                .map { index, item in
                    guard let transformed = transform(item) else {
                        throw YAMLConfigError.unexpectedScalarValueInArray(key.components, index)
                    }
                    return transformed
                }
        }
        let value = valueWrapper.value
        let content: ConfigContent
        switch type {
        case .string:
            guard case .scalar(let scalar) = value else {
                try throwMismatch()
            }
            content = .string(scalar.string)
        case .int:
            guard case .scalar(let scalar) = value, let int = Int.construct(from: scalar) else {
                try throwMismatch()
            }
            content = .int(int)
        case .double:
            guard case .scalar(let scalar) = value, let double = Double.construct(from: scalar) else {
                try throwMismatch()
            }
            content = .double(double)
        case .bool:
            guard case .scalar(let scalar) = value, let bool = Bool.construct(from: scalar) else {
                try throwMismatch()
            }
            content = .bool(bool)
        case .bytes:
            guard
                case .scalar(let scalar) = value,
                let bytesValue = bytesDecoder.decode(scalar.string)
            else {
                try throwMismatch()
            }
            content = .bytes(bytesValue)
        case .stringArray:
            guard case .sequence(let array) = value else {
                try throwMismatch()
            }
            content = .stringArray(array.map(\.string))
        case .intArray:
            content = .intArray(try getTypedArray(value, transform: Int.construct))
        case .doubleArray:
            content = .doubleArray(try getTypedArray(value, transform: Double.construct))
        case .boolArray:
            content = .boolArray(try getTypedArray(value, transform: Bool.construct))
        case .byteChunkArray:
            guard case .sequence(let array) = value else {
                try throwMismatch()
            }
            let byteChunkArray = try array.map { item in
                guard let bytesValue = bytesDecoder.decode(item.string) else {
                    try throwMismatch()
                }
                return bytesValue
            }
            content = .byteChunkArray(byteChunkArray)
        }
        return ConfigValue(content, isSecret: valueWrapper.isSecret)
    }
}

@available(Configuration 1.0, *)
extension YAMLProviderSnapshot: ConfigSnapshotProtocol {
    var providerName: String {
        "YAMLProvider"
    }

    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    func value(forKey key: AbsoluteConfigKey, type: ConfigType) throws -> LookupResult {
        let encodedKey = Self.keyEncoder.encode(key)
        return try withConfigValueLookup(encodedKey: encodedKey) {
            try values.withLock { (values) -> ConfigValue? in
                guard let value = values[encodedKey] else {
                    return nil
                }
                return try parseValue(
                    value,
                    key: key,
                    type: type
                )
            }
        }
    }
}

/// Parses the root emitted by Yams.
/// - Parameters:
///   - parsedDictionary: The parsed YAML mapping from Yams.
///   - keyEncoder: The key encoder.
///   - secretsSpecifier: The secrets specifier.
/// - Throws: When parsing fails.
/// - Returns: The parsed and validated YAML config values.
@available(Configuration 1.0, *)
internal func parseValues(
    _ parsedDictionary: Yams.Node.Mapping,
    keyEncoder: some ConfigKeyEncoder,
    secretsSpecifier: SecretsSpecifier<String, Void>
) throws -> [String: YAMLProviderSnapshot.ValueWrapper] {
    var values: [String: YAMLProviderSnapshot.ValueWrapper] = [:]
    var valuesToIterate: [([String], Yams.Node, Yams.Node)] = parsedDictionary.map { ([], $0, $1) }
    while !valuesToIterate.isEmpty {
        let (prefix, nodeKey, value) = valuesToIterate.removeFirst()
        guard let stringKey = nodeKey.string else {
            throw YAMLProviderSnapshot.YAMLConfigError.keyNotConvertibleToString(prefix)
        }
        let keyComponents = prefix + [stringKey]
        if let mapping = value.mapping {
            valuesToIterate.append(contentsOf: mapping.map { (keyComponents, $0, $1) })
        } else {
            let yamlValue: YAMLProviderSnapshot.YAMLValue
            if let sequence = value.sequence {
                let scalarArray = try sequence.enumerated()
                    .map { index, value in
                        guard let scalar = value.scalar else {
                            throw YAMLProviderSnapshot.YAMLConfigError.nonScalarValueInArray(keyComponents, index)
                        }
                        return scalar
                    }
                yamlValue = .sequence(scalarArray)
            } else if let scalar = value.scalar {
                yamlValue = .scalar(scalar)
            } else {
                throw YAMLProviderSnapshot.YAMLConfigError.unsupportedPrimitiveValue(keyComponents)
            }
            let encodedKey = keyEncoder.encode(AbsoluteConfigKey(keyComponents))
            let isSecret = secretsSpecifier.isSecret(key: encodedKey, value: ())
            values[encodedKey] = .init(value: yamlValue, isSecret: isSecret)
        }
    }
    return values
}

#endif
