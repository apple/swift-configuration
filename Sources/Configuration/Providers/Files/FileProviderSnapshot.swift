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

import SystemPackage
#if canImport(FoundationEssentials)
public import FoundationEssentials
#else
public import Foundation
#endif

/// A type that provides parsing options for file configuration snapshots.
///
/// This protocol defines the requirements for parsing options types used when creating
/// file-based configuration snapshots. Types conforming to this protocol can provide
/// additional configuration or processing parameters that affect how file data is
/// interpreted and parsed.
///
/// ## Usage
///
/// Implement this protocol to provide parsing options:
///
/// ```swift
/// struct MyParsingOptions: FileParsingOptionsProtocol {
///     let encoding: String.Encoding
///     let dateFormat: String?
///
///     static let `default` = MyParsingOptions(
///         encoding: .utf8,
///         dateFormat: nil
///     )
/// }
/// ```
@available(Configuration 1.0, *)
public protocol FileParsingOptionsProtocol: Sendable {
    /// The default instance of this options type.
    ///
    /// This property provides a default configuration that can be used when
    /// no parsing options are specified.
    static var `default`: Self { get }
}

/// A protocol for configuration snapshots created from file data.
///
/// This protocol extends ``ConfigSnapshotProtocol`` to provide file-specific functionality
/// for creating configuration snapshots from raw file data. Types conforming to this protocol
/// can parse various file formats (such as JSON and YAML) and convert them into configuration values.
///
/// Commonly used with ``FileProvider`` and ``ReloadingFileProvider``.
///
/// ## Implementation
///
/// To create a custom file configuration snapshot:
///
/// ```swift
/// struct MyFormatSnapshot: FileConfigSnapshotProtocol {
///     typealias ParsingOptions = MyParsingOptions
///
///     let values: [String: ConfigValue]
///     let providerName: String
///
///     init(data: Data, providerName: String, parsingOptions: MyParsingOptions) throws {
///         self.providerName = providerName
///         // Parse the data according to your format
///         self.values = try parseMyFormat(data, using: parsingOptions)
///     }
/// }
/// ```
///
/// The snapshot is responsible for parsing the file data and converting it into a
/// representation of configuration values that can be queried by the configuration system.
@available(Configuration 1.0, *)
public protocol FileConfigSnapshotProtocol: ConfigSnapshotProtocol, CustomStringConvertible,
    CustomDebugStringConvertible
{
    /// The parsing options type used for parsing this snapshot.
    associatedtype ParsingOptions: FileParsingOptionsProtocol

    /// Creates a new snapshot from file data.
    ///
    /// This initializer parses the provided file data and creates a snapshot
    /// containing the configuration values found in the file.
    ///
    /// - Parameters:
    ///   - data: The raw file data to parse.
    ///   - providerName: The name of the provider creating this snapshot.
    ///   - parsingOptions: Parsing options that affect parsing behavior.
    /// - Throws: If the file data cannot be parsed or contains invalid configuration.
    init(data: Data, providerName: String, parsingOptions: ParsingOptions) throws
}
