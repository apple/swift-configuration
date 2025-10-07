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

import SystemPackage

// Needs full Foundation for JSONSerialization.
import Foundation

/// A snapshot of configuration values parsed from JSON data.
///
/// This structure represents a point-in-time view of configuration values. It handles
/// the conversion from JSON types to configuration value types.
@available(Configuration 1.0, *)
internal struct JSONProviderSnapshot {
    /// The key encoder for JSON.
    static let keyEncoder: SeparatorKeyEncoder = .dotSeparated

    /// A JSON number-like value: an int, double, or a bool.
    ///
    /// This is needed because of how Foundation.JSONSerialization works on different platforms.
    enum JSONNumberIsh: CustomStringConvertible {

        /// A Boolean value.
        case bool(Bool)

        /// An integer value.
        case int(Int)

        /// A floating point value.
        case double(Double)

        var description: String {
            switch self {
            case .bool(let bool):
                return bool.description
            case .int(let int):
                return int.description
            case .double(let double):
                return double.description
            }
        }
    }

    /// A parsed JSON value compatible with the config system.
    enum JSONValue: CustomStringConvertible {

        /// A string value.
        case string(String)

        /// A number-ish value.
        case number(JSONNumberIsh)

        /// An empty array.
        case emptyArray

        /// A string array.
        case stringArray([String])

        /// A number-ish array.
        case numberArray([JSONNumberIsh])

        var description: String {
            switch self {
            case .string(let string):
                return "\(string)"
            case .number(let number):
                return "\(number)"
            case .emptyArray:
                return "[]"
            case .stringArray(let strings):
                return strings.map(\.description).joined(separator: ",")
            case .numberArray(let numbers):
                return numbers.map { "\($0)" }.joined(separator: ",")
            }
        }
    }

    /// A wrapper of a JSON value with the information of whether it's secret.
    internal struct ValueWrapper: CustomStringConvertible {

        /// The underlying JSON value.
        var value: JSONValue

        /// Whether it should be treated as secret and not logged in plain text.
        var isSecret: Bool

        var description: String {
            if isSecret {
                return "<REDACTED>"
            }
            return "\(value)"
        }
    }

    /// The internal JSON provider error type.
    internal enum JSONConfigError: Error, CustomStringConvertible {

        /// The top level JSON value was not an object.
        case topLevelJSONValueIsNotObject(FilePath)

        /// The primitive type returned by JSONSerialization is not supported.
        case unsupportedPrimitiveValue([String], String)

        /// Detected a heterogeneous array, which isn't supported.
        case unexpectedValueInArray([String], String)

        var description: String {
            switch self {
            case .topLevelJSONValueIsNotObject(let path):
                return "The top-level value of the JSON file must be an object. File: \(path)"
            case .unsupportedPrimitiveValue(let keyPath, let typeName):
                return "Unsupported primitive value type: \(typeName) at \(keyPath.joined(separator: "."))"
            case .unexpectedValueInArray(let keyPath, let typeName):
                return "Unexpected value type: \(typeName) in array at \(keyPath.joined(separator: "."))"
            }
        }
    }

    /// A decoder of bytes from a string.
    var bytesDecoder: any ConfigBytesFromStringDecoder

    /// The underlying config values.
    var values: [String: ValueWrapper]

    /// Creates a snapshot with pre-parsed values.
    ///
    /// - Parameters:
    ///   - values: The configuration values.
    ///   - bytesDecoder: The decoder for converting string values to bytes.
    init(
        values: [String: ValueWrapper],
        bytesDecoder: some ConfigBytesFromStringDecoder,
    ) {
        self.values = values
        self.bytesDecoder = bytesDecoder
    }

    /// Creates a snapshot by parsing JSON data from a file.
    ///
    /// This initializer reads JSON data from the specified file, parses it using
    /// `JSONSerialization`, and converts the parsed values into the internal
    /// configuration format. The top-level JSON value must be an object.
    ///
    /// - Parameters:
    ///   - filePath: The path of the JSON file to read.
    ///   - fileSystem: The file system interface for reading the file.
    ///   - bytesDecoder: The decoder for converting string values to bytes.
    ///   - secretsSpecifier: The specifier for identifying secret values.
    /// - Throws: An error if the JSON root is not an object, or any error from
    ///   file reading or JSON parsing.
    init(
        filePath: FilePath,
        fileSystem: some CommonProviderFileSystem,
        bytesDecoder: some ConfigBytesFromStringDecoder,
        secretsSpecifier: SecretsSpecifier<String, any Sendable>
    ) async throws {
        let fileContents = try await fileSystem.fileContents(atPath: filePath)
        guard let parsedDictionary = try JSONSerialization.jsonObject(with: fileContents) as? [String: any Sendable]
        else {
            throw JSONProviderSnapshot.JSONConfigError.topLevelJSONValueIsNotObject(filePath)
        }
        let values = try parseValues(
            parsedDictionary,
            keyEncoder: Self.keyEncoder,
            secretsSpecifier: secretsSpecifier
        )
        self.init(
            values: values,
            bytesDecoder: bytesDecoder,
        )
    }

    /// Parses config content from the provided JSON value.
    /// - Parameters:
    ///   - valueWrapper: The wrapped JSON value.
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
        func getIntIsh(_ number: JSONNumberIsh) throws -> Int {
            switch number {
            case .bool(let bool):
                return bool ? 1 : 0
            case .int(let int):
                return int
            case .double(let double):
                guard let int = Int(exactly: double) else {
                    try throwMismatch()
                }
                return int
            }
        }
        func getDoubleIsh(_ number: JSONNumberIsh) throws -> Double {
            switch number {
            case .bool(let bool):
                return bool ? 1 : 0
            case .int(let int):
                guard let double = Double(exactly: int) else {
                    try throwMismatch()
                }
                return double
            case .double(let double):
                return double
            }
        }
        func getBoolIsh(_ number: JSONNumberIsh) throws -> Bool {
            switch number {
            case .bool(let bool):
                return bool
            case .int(let int):
                return int != 0
            case .double(let double):
                return double != 0
            }
        }
        let value = valueWrapper.value
        let content: ConfigContent
        switch type {
        case .string:
            guard case .string(let string) = value else {
                try throwMismatch()
            }
            content = .string(string)
        case .int:
            guard case .number(let number) = value else {
                try throwMismatch()
            }
            content = .int(try getIntIsh(number))
        case .double:
            guard case .number(let number) = value else {
                try throwMismatch()
            }
            content = .double(try getDoubleIsh(number))
        case .bool:
            guard case .number(let number) = value else {
                try throwMismatch()
            }
            content = .bool(try getBoolIsh(number))
        case .bytes:
            guard
                case .string(let string) = value,
                let bytesValue = bytesDecoder.decode(string)
            else {
                try throwMismatch()
            }
            content = .bytes(bytesValue)
        case .stringArray:
            guard case .stringArray(let array) = value else {
                try throwMismatch()
            }
            content = .stringArray(array)
        case .intArray:
            guard case .numberArray(let array) = value else {
                try throwMismatch()
            }
            content = .intArray(try array.map(getIntIsh))
        case .doubleArray:
            guard case .numberArray(let array) = value else {
                try throwMismatch()
            }
            content = .doubleArray(try array.map(getDoubleIsh))
        case .boolArray:
            guard case .numberArray(let array) = value else {
                try throwMismatch()
            }
            content = .boolArray(try array.map(getBoolIsh))
        case .byteChunkArray:
            guard case .stringArray(let array) = value else {
                try throwMismatch()
            }
            let byteChunkArray = try array.map { stringValue in
                guard let bytesValue = bytesDecoder.decode(stringValue) else {
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
extension JSONProviderSnapshot: ConfigSnapshotProtocol {
    var providerName: String {
        "JSONProvider"
    }

    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    func value(forKey key: AbsoluteConfigKey, type: ConfigType) throws -> LookupResult {
        let encodedKey = Self.keyEncoder.encode(key)
        return try withConfigValueLookup(encodedKey: encodedKey) {
            guard let value = values[encodedKey] else {
                return nil
            }
            return try parseValue(value, key: key, type: type)
        }
    }
}

/// Parses a value emitted by JSONSerialization into a JSON config value.
/// - Parameters:
///   - parsedDictionary: The parsed JSON object from JSONSerialization.
///   - keyEncoder: The key encoder.
///   - secretsSpecifier: The secrets specifier.
/// - Throws: When parsing fails.
/// - Returns: The parsed and validated JSON config values.
@available(Configuration 1.0, *)
internal func parseValues(
    _ parsedDictionary: [String: any Sendable],
    keyEncoder: some ConfigKeyEncoder,
    secretsSpecifier: SecretsSpecifier<String, any Sendable>
) throws -> [String: JSONProviderSnapshot.ValueWrapper] {
    var values: [String: JSONProviderSnapshot.ValueWrapper] = [:]
    var valuesToIterate: [([String], any Sendable)] = parsedDictionary.map { ([$0], $1) }
    while !valuesToIterate.isEmpty {
        let (keyComponents, value) = valuesToIterate.removeFirst()
        if let dictionary = value as? [String: any Sendable] {
            valuesToIterate.append(contentsOf: dictionary.map { (keyComponents + [$0], $1) })
        } else {
            let primitiveValue: JSONProviderSnapshot.JSONValue?
            if let array = value as? [any Sendable] {
                if array.isEmpty {
                    primitiveValue = .emptyArray
                } else {
                    let firstValue = array[0]
                    if firstValue is String {
                        primitiveValue = .stringArray(
                            try array.enumerated()
                                .map { index, value in
                                    guard let string = value as? String else {
                                        throw JSONProviderSnapshot.JSONConfigError.unexpectedValueInArray(
                                            keyComponents + ["\(index)"],
                                            "\(type(of: value))"
                                        )
                                    }
                                    return string
                                }
                        )
                    } else if firstValue is Int || firstValue is Double || firstValue is Bool {
                        primitiveValue = .numberArray(
                            try array.enumerated()
                                .map { index, value in
                                    if let int = value as? Int {
                                        return .int(int)
                                    } else if let double = value as? Double {
                                        return .double(double)
                                    } else if let bool = value as? Bool {
                                        return .bool(bool)
                                    } else {
                                        throw JSONProviderSnapshot.JSONConfigError.unexpectedValueInArray(
                                            keyComponents + ["\(index)"],
                                            "\(type(of: value))"
                                        )
                                    }
                                }
                        )
                    } else {
                        throw JSONProviderSnapshot.JSONConfigError.unsupportedPrimitiveValue(
                            keyComponents + ["0"],
                            "\(type(of: firstValue))"
                        )
                    }
                }
            } else {
                if let string = value as? String {
                    primitiveValue = .string(string)
                } else if let int = value as? Int {
                    primitiveValue = .number(.int(int))
                } else if let double = value as? Double {
                    primitiveValue = .number(.double(double))
                } else if let bool = value as? Bool {
                    primitiveValue = .number(.bool(bool))
                } else if value is NSNull {
                    primitiveValue = nil
                } else {
                    throw JSONProviderSnapshot.JSONConfigError.unsupportedPrimitiveValue(
                        keyComponents,
                        "\(type(of: value))"
                    )
                }
            }
            guard let primitiveValue else {
                continue
            }
            let encodedKey = keyEncoder.encode(AbsoluteConfigKey(keyComponents))
            let isSecret = secretsSpecifier.isSecret(key: encodedKey, value: value)
            values[encodedKey] = .init(value: primitiveValue, isSecret: isSecret)
        }
    }
    return values
}

#endif
