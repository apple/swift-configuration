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

/// A value that can be stored in a configuration context.
///
/// Context values support common data types used for configuration metadata.
public enum ConfigContextValue: Sendable, Equatable, Hashable {

    /// A string value.
    case string(String)

    /// An integer value.
    case int(Int)

    /// A floating point value.
    case double(Double)

    /// A Boolean value.
    case bool(Bool)
}

extension ConfigContextValue: CustomStringConvertible {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public var description: String {
        switch self {
        case .string(let value):
            return value
        case .int(let value):
            return String(value)
        case .double(let value):
            return String(value)
        case .bool(let value):
            return String(value)
        }
    }
}

extension ConfigContextValue: ExpressibleByStringLiteral {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension ConfigContextValue: ExpressibleByIntegerLiteral {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public init(integerLiteral value: Int) {
        self = .int(value)
    }
}

extension ConfigContextValue: ExpressibleByFloatLiteral {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public init(floatLiteral value: Double) {
        self = .double(value)
    }
}

extension ConfigContextValue: ExpressibleByBooleanLiteral {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}

extension [String: ConfigContextValue] {
    /// Creates a sorted string representation of the context, used primarily for sorting and logging.
    ///
    /// This method creates a deterministic string by:
    /// 1. Sorting keys alphabetically.
    /// 2. Converting each key-value pair to a string in the format `key=value`.
    /// 3. Joining the key-value strings with semicolons.
    ///
    /// - Returns: A string representation of the context.
    internal var signatureString: String {
        guard !isEmpty else { return "" }
        return self.sorted { $0.key < $1.key }
            .map { key, value -> String in
                let valueStr: String
                switch value {
                case .string(let str): valueStr = str
                case .int(let num): valueStr = "\(num)"
                case .double(let num): valueStr = "\(num)"
                case .bool(let bool): valueStr = "\(bool)"
                }
                return "\(key)=\(valueStr)"
            }
            .joined(separator: ";")
    }
}
