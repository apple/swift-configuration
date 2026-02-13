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
///     var configInt: Int {
///         duration.components.0
///     }
///
///     init?(configInt: Int) {
///         self.duration = .seconds(configInt)
///     }
/// }
///
/// // Now you can use it with automatic conversion
/// let config = ConfigReader(provider: EnvironmentVariablesProvider())
/// let dbTimeout = config.int(forKey: "database.timeout", as: MyDuration.self)
/// ```
@available(Configuration 1.0, *)
public protocol ExpressibleByConfigInt: CustomStringConvertible {

    /// Creates an instance from a configuration integer value.
    ///
    /// - Parameter configInt: The integer value from the configuration provider.
    init?(configInt: Int)

    /// The underlying raw integer value.
    var configInt: Int { get }
}

@available(Configuration 1.0, *)
extension ExpressibleByConfigInt {
    public var description: String {
        "\(configInt)"
    }
}

@available(Configuration 1.0, *)
extension Duration: ExpressibleByConfigInt {
    public var configInt: Int {
        precondition(
            components.seconds <= Int64(Int.max) && components.seconds >= Int64(Int.min),
            "Duration seconds out of Int range"
        )
        return .init(components.seconds)
    }

    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public init?(configInt: Int) {
        self = .seconds(configInt)
    }
}
