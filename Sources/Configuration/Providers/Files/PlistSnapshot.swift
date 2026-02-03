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

#if Plist

// Needs full Foundation for PropertyListSerialization.
import Foundation

/// A snapshot of configuration values parsed from property list (plist) data.
///
/// This structure represents a point-in-time view of configuration values. It handles
/// the conversion from plist types to configuration value types.
///
/// ## Usage
///
/// Use with ``FileProvider`` or ``ReloadingFileProvider``:
///
/// ```swift
/// let provider = try await FileProvider<PlistSnapshot>(filePath: "/etc/config.plist")
/// let config = ConfigReader(provider: provider)
/// ```
@available(Configuration 1.0, *)
public struct PlistSnapshot {

    /// Parsing options for plist snapshot creation.
    ///
    /// This struct provides configuration options for parsing plist data into configuration snapshots,
    /// including byte decoding and secrets specification.
    public struct ParsingOptions: FileParsingOptions {
        /// A decoder of bytes from a string.
        public var bytesDecoder: any ConfigBytesFromStringDecoder

        /// A specifier for determining which configuration values should be treated as secrets.
        public var secretsSpecifier: SecretsSpecifier<String, any Sendable>

        /// Creates parsing options for plist snapshots.
        ///
        /// - Parameters:
        ///   - bytesDecoder: The decoder to use for converting string values to byte arrays.
        ///   - secretsSpecifier: The specifier for identifying secret values.
        public init(
            bytesDecoder: some ConfigBytesFromStringDecoder = .base64,
            secretsSpecifier: SecretsSpecifier<String, any Sendable> = .none
        ) {
            self.bytesDecoder = bytesDecoder
            self.secretsSpecifier = secretsSpecifier
        }

        /// The default parsing options.
        ///
        /// Uses base64 byte decoding and treats no values as secrets.
        public static var `default`: Self {
            .init()
        }
    }

    /// The key encoder for plist.
    static let keyEncoder: SeparatorKeyEncoder = .dotSeparated

    /// A plist number-like value: an int, double, or a bool.            
    enum PlistNumberIsh: CustomStringConvertible {

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

    /// A parsed plist value compatible with the config system.
    enum PlistValue: CustomStringConvertible {

        /// A string value.
        case string(String)

        /// A number-ish value.
        case number(PlistNumberIsh)

        /// A data value.
        case data(Data)

        /// An empty array (type cannot be determined without elements).
        case emptyArray

        /// A string array.
        case stringArray([String])

        /// A number-ish array.
        case numberArray([PlistNumberIsh])

        /// A data array.
        case dataArray([Data])

        var description: String {
            switch self {
            case .string(let string):
                return string
            case .number(let number):
                return "\(number)"
            case .data(let data):
                return data.base64EncodedString()
            case .emptyArray:
                return "[]"
            case .stringArray(let strings):
                return strings.map(\.description).joined(separator: ",")
            case .numberArray(let numbers):
                return numbers.map { "\($0)" }.joined(separator: ",")
            case .dataArray(let array):
                return array.map { $0.base64EncodedString() }.joined(separator: ",")
            }
        }
    }

    /// A wrapper of a plist value with the information of whether it's secret.
    internal struct ValueWrapper: CustomStringConvertible {

        /// The underlying plist value.
        var value: PlistValue

        /// Whether it should be treated as secret and not logged in plain text.
        var isSecret: Bool

        var description: String {
            if isSecret {
                return "<REDACTED>"
            }
            return "\(value)"
        }
    }

    /// The internal plist provider error type.
    internal enum PlistConfigError: Error, CustomStringConvertible {

        /// The top level plist value was not a dictionary.
        case topLevelPlistValueIsNotDictionary

        /// The primitive type returned by PropertyListSerialization is not supported.
        case unsupportedPrimitiveValue([String], String)

        /// Detected a heterogeneous array, which isn't supported.
        case unexpectedValueInArray([String], String)

        var description: String {
            switch self {
            case .topLevelPlistValueIsNotDictionary:
                return "The top-level value of the plist file must be a dictionary."
            case .unsupportedPrimitiveValue(let keyPath, let typeName):
                return "Unsupported primitive value type: \(typeName) at \(keyPath.joined(separator: "."))"
            case .unexpectedValueInArray(let keyPath, let typeName):
                return "Unexpected value type: \(typeName) in array at \(keyPath.joined(separator: "."))"
            }
        }
    }

    /// The underlying config values.
    var values: [String: ValueWrapper]

    /// The name of the provider that created this snapshot.
    public let providerName: String

    /// A decoder of bytes from a string.
    var bytesDecoder: any ConfigBytesFromStringDecoder

    /// Parses config content from the provided plist value.
    /// - Parameters:
    ///   - valueWrapper: The wrapped plist value.
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
        func getIntIsh(_ number: PlistNumberIsh) throws -> Int {
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
        func getDoubleIsh(_ number: PlistNumberIsh) throws -> Double {
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
        func getBoolIsh(_ number: PlistNumberIsh) throws -> Bool {
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
            switch value {
            case .data(let data):
                content = .bytes([UInt8](data))
            case .string(let string):
                guard let bytesValue = bytesDecoder.decode(string) else {
                    try throwMismatch()
                }
                content = .bytes(bytesValue)
            default:
                try throwMismatch()
            }
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
            switch value {
            case .dataArray(let array):
                content = .byteChunkArray(array.map { [UInt8]($0) })
            case .stringArray(let array):
                let byteChunkArray = try array.map { stringValue in
                    guard let bytesValue = bytesDecoder.decode(stringValue) else {
                        try throwMismatch()
                    }
                    return bytesValue
                }
                content = .byteChunkArray(byteChunkArray)
            default:
                try throwMismatch()
            }
        }
        return ConfigValue(content, isSecret: valueWrapper.isSecret)
    }
}

@available(Configuration 1.0, *)
extension PlistSnapshot: FileConfigSnapshot {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public init(data: RawSpan, providerName: String, parsingOptions: ParsingOptions) throws {
        let plistData = data.withUnsafeBytes { buffer in
            Data(buffer)
        }
        guard let parsedDictionary = try PropertyListSerialization.propertyList(
            from: plistData,
            format: nil
        ) as? [String: any Sendable] else {
            throw PlistConfigError.topLevelPlistValueIsNotDictionary
        }
        let values = try parsePlistValues(
            parsedDictionary,
            keyEncoder: Self.keyEncoder,
            secretsSpecifier: parsingOptions.secretsSpecifier
        )
        self.init(
            values: values,
            providerName: providerName,
            bytesDecoder: parsingOptions.bytesDecoder
        )
    }
}

@available(Configuration 1.0, *)
extension PlistSnapshot: ConfigSnapshot {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public func value(forKey key: AbsoluteConfigKey, type: ConfigType) throws -> LookupResult {
        let encodedKey = Self.keyEncoder.encode(key)
        return try withConfigValueLookup(encodedKey: encodedKey) {
            guard let value = values[encodedKey] else {
                return nil
            }
            return try parseValue(value, key: key, type: type)
        }
    }
}

@available(Configuration 1.0, *)
extension PlistSnapshot: CustomStringConvertible {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public var description: String {
        "\(providerName)[\(values.count) values]"
    }
}

@available(Configuration 1.0, *)
extension PlistSnapshot: CustomDebugStringConvertible {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public var debugDescription: String {
        let prettyValues =
            values
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: ", ")
        return "\(providerName)[\(values.count) values: \(prettyValues)]"
    }
}

/// Parses a value emitted by PropertyListSerialization into a plist config value.
/// - Parameters:
///   - parsedDictionary: The parsed plist dictionary from PropertyListSerialization.
///   - keyEncoder: The key encoder.
///   - secretsSpecifier: The secrets specifier.
/// - Throws: When parsing fails.
/// - Returns: The parsed and validated plist config values.
@available(Configuration 1.0, *)
internal func parsePlistValues(
    _ parsedDictionary: [String: any Sendable],
    keyEncoder: some ConfigKeyEncoder,
    secretsSpecifier: SecretsSpecifier<String, any Sendable>
) throws -> [String: PlistSnapshot.ValueWrapper] {
    var values: [String: PlistSnapshot.ValueWrapper] = [:]
    var valuesToIterate: [([String], any Sendable)] = parsedDictionary.map { ([$0], $1) }
    while !valuesToIterate.isEmpty {
        let (keyComponents, value) = valuesToIterate.removeFirst()
        if let dictionary = value as? [String: any Sendable] {
            valuesToIterate.append(contentsOf: dictionary.map { (keyComponents + [$0], $1) })
        } else {
            let primitiveValue: PlistSnapshot.PlistValue?
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
                                        throw PlistSnapshot.PlistConfigError.unexpectedValueInArray(
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
                                        throw PlistSnapshot.PlistConfigError.unexpectedValueInArray(
                                            keyComponents + ["\(index)"],
                                            "\(type(of: value))"
                                        )
                                    }
                                }
                        )
                    } else if firstValue is Data {
                        primitiveValue = .dataArray(
                            try array.enumerated()
                                .map { index, value in
                                    guard let data = value as? Data else {
                                        throw PlistSnapshot.PlistConfigError.unexpectedValueInArray(
                                            keyComponents + ["\(index)"],
                                            "\(type(of: value))"
                                        )
                                    }
                                    return data
                                }
                        )
                    } else {
                        throw PlistSnapshot.PlistConfigError.unsupportedPrimitiveValue(
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
                } else if let data = value as? Data {
                    primitiveValue = .data(data)
                } else {
                    throw PlistSnapshot.PlistConfigError.unsupportedPrimitiveValue(
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
