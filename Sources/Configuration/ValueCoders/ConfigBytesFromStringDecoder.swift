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

/// A protocol for decoding string configuration values into byte arrays.
///
/// This protocol defines the interface for converting string-based configuration
/// values into binary data. Different implementations can support various encoding
/// formats such as base64, hexadecimal, or other custom encodings.
///
/// ## Usage
///
/// Implementations of this protocol are used by configuration providers that
/// need to convert string values to binary data, such as cryptographic keys,
/// certificates, or other binary configuration data.
///
/// ```swift
/// let decoder: ConfigBytesFromStringDecoder = .base64
/// let bytes = decoder.decode("SGVsbG8gV29ybGQ=") // "Hello World" in base64
/// ```
public protocol ConfigBytesFromStringDecoder: Sendable {

    /// Decodes a string value into an array of bytes.
    ///
    /// This method attempts to parse the provided string according to the
    /// decoder's specific format and returns the corresponding byte array.
    /// If the string cannot be decoded (due to invalid format or encoding),
    /// the method returns `nil`.
    ///
    /// - Parameter value: The string representation to decode.
    /// - Returns: An array of bytes if decoding succeeds, or `nil` if it fails.
    func decode(_ value: String) -> [UInt8]?
}

/// A decoder that converts base64-encoded strings into byte arrays.
///
/// This decoder interprets string configuration values as base64-encoded data
/// and converts them to their binary representation.
public struct ConfigBytesFromBase64StringDecoder: Sendable {

    /// Creates a new base64 decoder.
    public init() {}
}

extension ConfigBytesFromBase64StringDecoder: ConfigBytesFromStringDecoder {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public func decode(_ value: String) -> [UInt8]? {
        guard let data = Data(base64Encoded: value) else {
            return nil
        }
        return Array(data)
    }
}

extension ConfigBytesFromStringDecoder where Self == ConfigBytesFromBase64StringDecoder {

    /// A decoder that interprets string values as base64-encoded data.
    public static var base64: Self { .init() }
}

/// A decoder that converts hexadecimal-encoded strings into byte arrays.
///
/// This decoder interprets string configuration values as hexadecimal-encoded
/// data and converts them to their binary representation. It expects strings
/// to contain only valid hexadecimal characters (0-9, A-F, a-f).
///
/// ## Hexadecimal format
///
/// The decoder expects strings with an even number of characters, where each
/// pair of characters represents one byte. For example, "48656C6C6F" represents
/// the bytes for "Hello".
public struct ConfigBytesFromHexStringDecoder: Sendable {

    /// Creates a new hexadecimal decoder.
    public init() {}
}

extension ConfigBytesFromHexStringDecoder: ConfigBytesFromStringDecoder {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public func decode(_ value: String) -> [UInt8]? {
        if value.count % 2 != 0 {
            return nil
        }
        var bytes: [UInt8] = []
        bytes.reserveCapacity(value.count / 2)
        var index = value.startIndex
        while index < value.endIndex {
            let nextIndex = value.index(index, offsetBy: 2)
            let byteString = value[index..<nextIndex]
            guard let byte = UInt8(byteString, radix: 16) else {
                return nil
            }
            bytes.append(byte)
            index = nextIndex
        }
        return bytes
    }
}

extension ConfigBytesFromStringDecoder where Self == ConfigBytesFromHexStringDecoder {

    /// A decoder that interprets string values as hexadecimal-encoded data.
    public static var hex: Self { .init() }
}
