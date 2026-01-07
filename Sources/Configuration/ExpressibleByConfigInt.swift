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

/// A protocol for types that can be initialized from configuration integer values.
///
/// Conform your custom types to this protocol to enable automatic conversion when using
/// the `as:` parameter with configuration reader methods such as ``ConfigReader/int(forKey:as:isSecret:fileID:line:)-11fn2``.
///
/// > Tip: If your type is an integer-based enum, you don't need to explicitly conform it to
/// > ``ExpressibleByConfigInt``, as the same conversions work for types
/// > that conform to `RawRepresentable` with an `Int` raw value automatically.
///
/// ## Custom types
///
/// For other custom types, conform to the protocol ``ExpressibleByConfigInt`` by providing a failable initializer
/// and the `description` property:
///
/// ```swift
/// struct MyDuration: ExpressibleByConfigInt {
///     let duration: Duration
///
///     init?(configInt: Int) {
///         self.duration = .seconds(configInt)
///     }
///
///     var description: String { duration.description }
/// }
///
/// // Now you can use it with automatic conversion
/// let config = ConfigReader(provider: EnvironmentVariablesProvider())
/// let dbUrl = config.int(forKey: "database.timeout", as: MyDuration.self)
/// ```
@available(Configuration 1.0, *)
public protocol ExpressibleByConfigInt: CustomStringConvertible {

    /// Creates an instance from a configuration integer value.
    ///
    /// - Parameter configInt: The integer value from the configuration provider.
    init?(configInt: Int)
}

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
@available(Configuration 1.0, *)
extension Duration: ExpressibleByConfigInt {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public init?(configInt: Int) {
        self = .seconds(configInt)
    }
}
