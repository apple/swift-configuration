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

/// A type that provides parsing options for file configuration snapshots.
///
/// This protocol defines the requirements for parsing options types used with ``FileConfigSnapshot``
/// implementations. Types conforming to this protocol provide configuration parameters that control
/// how file data is interpreted and parsed during snapshot creation.
///
/// The parsing options are passed to the ``FileConfigSnapshot/init(data:providerName:parsingOptions:)``
/// initializer, allowing custom file format implementations to access format-specific parsing
/// settings such as character encoding, date formats, or validation rules.
///
/// ## Usage
///
/// Implement this protocol to provide parsing options for your custom ``FileConfigSnapshot``:
///
/// ```swift
/// struct MyParsingOptions: FileParsingOptions {
///     let encoding: String.Encoding
///     let dateFormat: String?
///     let strictValidation: Bool
///
///     static let `default` = MyParsingOptions(
///         encoding: .utf8,
///         dateFormat: nil,
///         strictValidation: false
///     )
/// }
///
/// struct MyFormatSnapshot: FileConfigSnapshot {
///     typealias ParsingOptions = MyParsingOptions
///
///     init(data: RawSpan, providerName: String, parsingOptions: ParsingOptions) throws {
///         // Implementation that inspects `parsingOptions` properties like `encoding`,
///         // `dateFormat`, and `strictValidation`.
///     }
/// }
/// ```
@available(Configuration 1.0, *)
public protocol FileParsingOptions: Sendable {
    /// The default instance of this options type.
    ///
    /// This property provides a default configuration that can be used when
    /// no parsing options are specified.
    static var `default`: Self { get }
}

/// A protocol for configuration snapshots created from file data.
///
/// This protocol extends ``ConfigSnapshot`` to provide file-specific functionality
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
/// struct MyFormatSnapshot: FileConfigSnapshot {
///     typealias ParsingOptions = MyParsingOptions
///
///     let values: [String: ConfigValue]
///     let providerName: String
///
///     init(data: RawSpan, providerName: String, parsingOptions: MyParsingOptions) throws {
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
public protocol FileConfigSnapshot: ConfigSnapshot, CustomStringConvertible,
    CustomDebugStringConvertible
{
    /// The parsing options type used for parsing this snapshot.
    associatedtype ParsingOptions: FileParsingOptions

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
    init(data: RawSpan, providerName: String, parsingOptions: ParsingOptions) throws
}

@available(Configuration 1.0, *)
internal struct EmptyFileConfigSnapshot: Sendable {
    var providerName: String
}

@available(Configuration 1.0, *)
extension EmptyFileConfigSnapshot: ConfigSnapshot {
    func value(forKey key: AbsoluteConfigKey, type: ConfigType) throws -> LookupResult {
        .init(encodedKey: key.description, value: nil)
    }
}

@available(Configuration 1.0, *)
extension EmptyFileConfigSnapshot: CustomStringConvertible {
    var description: String {
        "\(providerName)[empty]"
    }
}

@available(Configuration 1.0, *)
extension EmptyFileConfigSnapshot: CustomDebugStringConvertible {
    var debugDescription: String {
        description
    }
}
