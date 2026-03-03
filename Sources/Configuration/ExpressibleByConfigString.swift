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

/// A protocol for types that can be initialized from configuration string values.
///
/// Conform your custom types to this protocol to enable automatic conversion when using
/// the `as:` parameter with configuration reader methods such as ``ConfigReader/string(forKey:as:isSecret:fileID:line:)-4oust``.
///
/// > Tip: If your type is a string-based enum, you don't need to explicitly conform it to
/// > ``ExpressibleByConfigString``, as the same conversions work for types
/// > that conform to `RawRepresentable` with a `String` raw value automatically.
///
/// ## Custom types
///
/// For other custom types, conform to the protocol ``ExpressibleByConfigString`` by providing a failable initializer
/// and the `description` property:
///
/// ```swift
/// struct DatabaseURL: ExpressibleByConfigString {
///     let url: URL
///
///     init?(configString: String) {
///         guard let url = URL(string: configString) else { return nil }
///         self.url = url
///     }
///
///     var description: String { url.absoluteString }
/// }
///
/// // Now you can use it with automatic conversion
/// let config = ConfigReader(provider: EnvironmentVariablesProvider())
/// let dbUrl = config.string(forKey: "database.url", as: DatabaseURL.self)
/// ```
///
/// ## Built-in conformances
///
/// The following Foundation types already conform to ``ExpressibleByConfigString``:
/// - `SystemPackage.FilePath` - Converts from file paths.
/// - `Foundation.URL` - Converts from URL strings.
/// - `Foundation.UUID` - Converts from UUID strings.
/// - `Foundation.Date` - Converts from ISO8601 date strings.
@available(Configuration 1.0, *)
public protocol ExpressibleByConfigString: CustomStringConvertible {

    /// Creates an instance from a configuration string value.
    ///
    /// - Parameter configString: The string value from the configuration provider.
    init?(configString: String)
}

@available(Configuration 1.0, *)
extension URL: ExpressibleByConfigString {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public init?(configString: String) {
        self.init(string: configString)
    }
}

@available(Configuration 1.0, *)
extension FilePath: ExpressibleByConfigString {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public init?(configString: String) {
        self.init(configString)
    }
}

@available(Configuration 1.0, *)
extension UUID: ExpressibleByConfigString {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public init?(configString: String) {
        self.init(uuidString: configString)
    }
}

@available(Configuration 1.0, *)
extension Date: ExpressibleByConfigString {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public init?(configString: String) {
        guard let date = try? Date.ISO8601FormatStyle.iso8601.parse(configString) else {
            return nil
        }
        self = date
    }
}
