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

/// A configuration key representing a relative path to a configuration value.
///
/// Configuration keys consist of hierarchical string components forming paths similar to
/// file system paths or JSON object keys. For example, `["http", "timeout"]` represents
/// the `timeout` value nested under `http`.
///
/// Keys support additional context information that providers can use to refine lookups
/// or provide specialized behavior.
///
/// ## Usage
///
/// Create keys using string literals, arrays, or the initializers:
///
/// ```swift
/// let key1: ConfigKey = "database.connection.timeout"
/// let key2 = ConfigKey(["api", "endpoints", "primary"])
/// let key3 = ConfigKey("server.port", context: ["environment": .string("production")])
/// ```
@available(Configuration 1.0, *)
public struct ConfigKey: Sendable {

    /// The hierarchical components that make up this configuration key.
    ///
    /// Each component represents a level in the configuration hierarchy. For example,
    /// `["database", "connection", "timeout"]` represents a three-level nested key.
    public var components: [String]

    /// Additional context information for this configuration key.
    ///
    /// Context provides extra information that providers can use to refine lookups
    /// or return more specific values. Not all providers use context information.
    public var context: [String: ConfigContextValue]

    /// Creates a new configuration key.
    /// - Parameters:
    ///   - components: The hierarchical components that make up the key path.
    ///   - context: Additional context information for the key.
    public init(_ components: [String], context: [String: ConfigContextValue] = [:]) {
        self.components = components
        self.context = context
    }

    /// Creates a new configuration key.
    /// - Parameters:
    ///   - string: The string representation of the key path, for example `"http.timeout"`.
    ///   - context: Additional context information for the key.
    public init(_ string: String, context: [String: ConfigContextValue] = [:]) {
        self = DotSeparatorKeyDecoder.decode(string, context: context)
    }
}

@available(Configuration 1.0, *)
extension ConfigKey: Equatable {}

@available(Configuration 1.0, *)
extension ConfigKey: Hashable {}

@available(Configuration 1.0, *)
extension ConfigKey: Comparable {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public static func < (lhs: ConfigKey, rhs: ConfigKey) -> Bool {
        let lhsCount = lhs.components.count
        let rhsCount = rhs.components.count
        for i in 0..<min(lhsCount, rhsCount) {
            let lhsValue = lhs.components[i]
            let rhsValue = rhs.components[i]
            if lhsValue == rhsValue {
                continue
            } else {
                return lhsValue < rhsValue
            }
        }
        if lhs.context.signatureString != rhs.context.signatureString {
            return lhs.context.signatureString < rhs.context.signatureString
        }
        return lhsCount < rhsCount
    }
}

@available(Configuration 1.0, *)
extension ConfigKey: CustomStringConvertible {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public var description: String {
        let keyString = components.joined(separator: ".")
        let contextString = context.signatureString
        if contextString.isEmpty {
            return keyString
        }
        return "\(keyString) [\(contextString)]"
    }
}

@available(Configuration 1.0, *)
extension ConfigKey: ExpressibleByStringLiteral {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public init(stringLiteral value: String) {
        self = DotSeparatorKeyDecoder.decode(value, context: [:])
    }
}

@available(Configuration 1.0, *)
extension ConfigKey: ExpressibleByArrayLiteral {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public init(arrayLiteral elements: String...) {
        self.init(elements)
    }
}

/// A configuration key that represents an absolute path to a configuration value.
///
/// Absolute configuration keys are similar to relative keys but represent complete
/// paths from the root of the configuration hierarchy. They are used internally
/// by the configuration system after resolving any key prefixes or scoping.
///
/// Like relative keys, absolute keys consist of hierarchical components and
/// optional context information.
@available(Configuration 1.0, *)
public struct AbsoluteConfigKey: Sendable {

    /// The hierarchical components that make up this absolute configuration key.
    ///
    /// Each component represents a level in the configuration hierarchy, forming
    /// a complete path from the root of the configuration structure.
    public var components: [String]

    /// Additional context information for this configuration key.
    ///
    /// Context provides extra information that providers can use to refine lookups
    /// or return more specific values. Not all providers use context information.
    public var context: [String: ConfigContextValue]

    /// Creates a new absolute configuration key.
    /// - Parameters:
    ///   - components: The hierarchical components that make up the complete key path.
    ///   - context: Additional context information for the key.
    public init(_ components: [String], context: [String: ConfigContextValue] = [:]) {
        self.components = components
        self.context = context
    }
}

@available(Configuration 1.0, *)
extension AbsoluteConfigKey: Equatable {}

@available(Configuration 1.0, *)
extension AbsoluteConfigKey: Hashable {}

@available(Configuration 1.0, *)
extension AbsoluteConfigKey: Comparable {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public static func < (lhs: AbsoluteConfigKey, rhs: AbsoluteConfigKey) -> Bool {
        let lhsCount = lhs.components.count
        let rhsCount = rhs.components.count
        for i in 0..<min(lhsCount, rhsCount) {
            let lhsValue = lhs.components[i]
            let rhsValue = rhs.components[i]
            if lhsValue == rhsValue {
                continue
            } else {
                return lhsValue < rhsValue
            }
        }
        if lhs.context.signatureString != rhs.context.signatureString {
            return lhs.context.signatureString < rhs.context.signatureString
        }
        return lhsCount < rhsCount
    }
}

@available(Configuration 1.0, *)
extension AbsoluteConfigKey: CustomStringConvertible {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public var description: String {
        let keyString = components.joined(separator: ".")
        let contextString = context.signatureString
        if contextString.isEmpty {
            return keyString
        }
        return "\(keyString) [\(contextString)]"
    }
}

@available(Configuration 1.0, *)
extension AbsoluteConfigKey {

    /// Creates a new absolute configuration key from a relative key.
    /// - Parameter relative: The relative configuration key to convert.
    public init(_ relative: ConfigKey) {
        self.init(relative.components, context: relative.context)
    }
}

@available(Configuration 1.0, *)
extension AbsoluteConfigKey? {
    /// Returns a new absolute configuration key by appending the given relative key.
    /// - Parameter relative: The relative configuration key to append to this key.
    /// - Returns: A new absolute configuration key with the relative key appended.
    internal func appending(_ relative: ConfigKey) -> AbsoluteConfigKey {
        switch self {
        case .none:
            return .init(relative)
        case .some(var wrapped):
            wrapped.components.append(contentsOf: relative.components)
            wrapped.context.merge(relative.context) { $1 }
            return wrapped
        }
    }
}

@available(Configuration 1.0, *)
extension AbsoluteConfigKey {
    /// Returns a new absolute configuration key by prepending the given relative key.
    /// - Parameter prefix: The relative configuration key to prepend to this key.
    /// - Returns: A new absolute configuration key with the prefix prepended.
    public func prepending(_ prefix: ConfigKey) -> AbsoluteConfigKey {
        var prefixedComponents = prefix.components
        prefixedComponents.append(contentsOf: self.components)
        var mergedContext = prefix.context
        mergedContext.merge(self.context) { $1 }
        return AbsoluteConfigKey(prefixedComponents, context: mergedContext)
    }

    /// Returns a new absolute configuration key by appending the given relative key.
    /// - Parameter relative: The relative configuration key to append to this key.
    /// - Returns: A new absolute configuration key with the relative key appended.
    public func appending(_ relative: ConfigKey) -> AbsoluteConfigKey {
        var appended = self
        appended.components.append(contentsOf: relative.components)
        appended.context.merge(relative.context) { $1 }
        return appended
    }
}

@available(Configuration 1.0, *)
extension AbsoluteConfigKey: ExpressibleByStringLiteral {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public init(stringLiteral value: String) {
        self = .init(DotSeparatorKeyDecoder.decode(value, context: [:]))
    }
}

@available(Configuration 1.0, *)
extension AbsoluteConfigKey: ExpressibleByArrayLiteral {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public init(arrayLiteral elements: String...) {
        self.init(elements)
    }
}
