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

#if CommandLineArguments

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// A lightweight parser for command-line arguments.
///
/// Converts `CommandLine.arguments` into a structured format for configuration lookup.
///
/// ## Supported formats
///
/// - `--key value`: A key-value pair with separate arguments.
/// - `--key=value`: A key-value pair with an equals sign.
/// - `--flag`: A Boolean flag, followed by no values.
/// - `--key val1 val2`: A key with multiple values (an array).
///
/// ## Usage
///
/// ```swift
/// let parser = CLIArgumentParser()
/// let parsed = parser.parse(CommandLine.arguments)
///
/// // Results in [String: [String]] format
/// // "--verbose": []              -> boolean flag
/// // "--host": ["localhost"]      -> single value
/// // "--ports": ["8080", "8443"]  -> multiple values (an array)
/// ```
internal struct CLIArgumentParser {

    /// Parses command-line arguments into key-value pairs.
    ///
    /// Processes the arguments array and extracts CLI options with their values.
    /// The program name (first argument) is automatically skipped.
    ///
    /// ```swift
    /// let args = ["program", "--verbose", "--host", "localhost", "--ports", "8080", "8443"]
    /// let parsed = parser.parse(args)
    /// // Results in:
    /// // ["--verbose": [], "--host": ["localhost"], "--ports": ["8080", "8443"]]
    /// ```
    ///
    /// - Parameter arguments: The command-line arguments array (typically `CommandLine.arguments`).
    /// - Returns: A dictionary containing option names and their accumulated values.
    func parse(_ arguments: [String]) -> [String: [String]] {
        var result: [String: [String]] = [:]
        var currentKey: String?
        var currentValues: [String] = []

        // Skip program name (index 0)
        let args = Array(arguments.dropFirst())

        for arg in args {
            if arg.hasPrefix("--") {
                // Save previous key-value pair if any
                if let key = currentKey {
                    let processedValues = processValues(currentValues)
                    result[key, default: []].append(contentsOf: processedValues)
                    currentValues = []
                }

                // Handle the `--key=value` format
                if let equalIndex = arg.firstIndex(of: "=") {
                    let key = String(arg[..<equalIndex])
                    let value = String(arg[arg.index(after: equalIndex)...])
                    let processedValues = processValues([value])
                    result[key, default: []].append(contentsOf: processedValues)
                    currentKey = nil
                } else {
                    // Handle the `--key` format, followed by 0 or more values
                    currentKey = arg
                }
            } else if let _ = currentKey {
                // This is a value for the current key
                currentValues.append(arg)
            }
            // Ignore non-option arguments that don't belong to any key
        }

        // Save the last key-value pair
        if let key = currentKey {
            let processedValues = processValues(currentValues)
            result[key, default: []].append(contentsOf: processedValues)
        }

        return result
    }

    /// Processes raw CLI values by splitting comma-separated entries.
    ///
    /// Handles comma-separated values within individual CLI arguments, allowing
    /// formats like `--tags a,b,c` to be parsed as separate values.
    ///
    /// ```swift
    /// processValues(["a,b", "c"]) // Returns ["a", "b", "c"]
    /// processValues(["single"])   // Returns ["single"]
    /// processValues([""])         // Returns [""]
    /// processValues([])           // Returns []
    /// ```
    ///
    /// - Parameter values: The raw string values from CLI arguments.
    /// - Returns: An array of processed values with comma-separated entries split.
    private func processValues(_ values: [String]) -> [String] {
        values.flatMap { value in
            // Handle empty strings specially to preserve them (for example, `--key=`).
            if value.isEmpty {
                return [""]
            }
            return value.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        }
    }
}

#endif
