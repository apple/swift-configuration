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

/// A parser for environment files in the standard `.env` format.
///
/// This parser processes environment files that contain key-value pairs in the format
/// `KEY=value`, one per line. It handles common environment file conventions including
/// comments, whitespace, and duplicate key resolution.
///
/// ## File format
///
/// The parser supports the standard environment file format:
/// ```
/// # This is a comment
/// DATABASE_HOST=localhost
/// DATABASE_PORT=5432
///
/// # Empty lines are ignored
/// API_KEY=secret-key-here
/// ```
///
/// ## Parsing behavior
///
/// The parser implements lenient parsing with these rules:
/// - Lines containing only whitespace are ignored
/// - Lines starting with `#` are treated as comments and ignored
/// - Lines without an `=` character are ignored
/// - Lines where the key is empty (starts with `=`) are ignored
/// - When duplicate keys are found, the last occurrence takes precedence
/// - Values can contain `=` characters (only the first `=` is used as separator)
@available(Configuration 1.0, *)
struct EnvironmentFileParser {
    /// Parses environment file contents into a dictionary of key-value pairs.
    ///
    /// This method processes the provided string content line by line, extracting
    /// environment variable definitions while gracefully handling malformed lines
    /// and comments.
    ///
    /// ```swift
    /// let content = """
    /// # Database configuration
    /// DB_HOST=localhost
    /// DB_PORT=5432
    /// DB_NAME=myapp
    /// """
    /// let variables = EnvironmentFileParser.parsed(content)
    /// // Results in ["DB_HOST": "localhost", "DB_PORT": "5432", "DB_NAME": "myapp"]
    /// ```
    ///
    /// - Parameter contents: The string contents of the environment file to parse.
    /// - Returns: A dictionary mapping environment variable names to their values.
    static func parsed(_ contents: String) -> [String: String] {
        let pairs =
            contents
            .split(separator: "\n")
            .map { $0.trimmed() }
            .compactMap { pair -> (String, String)? in
                let components =
                    pair
                    .split(separator: "=", maxSplits: 1)
                    .map { $0.trimmed() }
                if components.count != 2 || components[0].isEmpty || components[0].utf8.first == UInt8(ascii: "#") {
                    return nil
                }
                return (components[0], components[1])
            }
        return Dictionary(
            pairs,
            uniquingKeysWith: { a, b in b }
        )
    }
}
