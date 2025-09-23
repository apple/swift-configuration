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

/// A key encoder that transforms configuration keys into CLI options.
///
/// Converts hierarchical configuration keys into CLI option names with camelCase to
/// dash-case conversion and proper `--` prefix formatting.
///
/// ## Encoding rules
///
/// 1. Converts camelCase to dash-case (for example, `serverTimeout` → `server-timeout`).
/// 2. Joins all components with dashes.
/// 3. Adds the `--` prefix for the conventional CLI option format.
/// 4. Converts to lowercase for consistency.
///
/// ```swift
/// let encoder = CLIKeyEncoder()
///
/// // Basic hierarchical key
/// encoder.encode(["database", "host"]) // "--database-host"
///
/// // CamelCase handling
/// encoder.encode(["http", "serverTimeout"]) // "--http-server-timeout"
///
/// // Multi-level hierarchy
/// encoder.encode(["app", "database", "connectionPool", "maxSize"]) // "--app-database-connection-pool-max-size"
/// ```
internal struct CLIKeyEncoder {

    /// Converts a camelCase string to dash-case.
    ///
    /// Detects word boundaries in camelCase strings and inserts dashes at
    /// appropriate locations.
    ///
    /// ```swift
    /// convertCamelCaseToDashCase("serverTimeout") // "server-timeout"
    /// convertCamelCaseToDashCase("maxRetryCount") // "max-retry-count"
    /// convertCamelCaseToDashCase("simple") // "simple"
    /// ```
    ///
    /// - Parameter input: The camelCase string to convert.
    /// - Returns: The dash-case equivalent.
    private func convertCamelCaseToDashCase(_ input: String) -> String {
        guard input.count >= 2 else {
            return input.lowercased()
        }
        var result = input
        var index = result.startIndex
        while index < result.index(before: result.endIndex) {
            let currentChar = result[index]
            let nextIndex = result.index(after: index)
            let nextChar = result[nextIndex]

            // Insert dash between lowercase and uppercase characters
            if currentChar.isLowercase && nextChar.isUppercase {
                result.insert("-", at: nextIndex)
                // Skip the inserted dash
                index = result.index(after: nextIndex)
            } else {
                index = nextIndex
            }
        }
        return result.lowercased()
    }
}

extension CLIKeyEncoder: ConfigKeyEncoder {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    func encode(_ key: AbsoluteConfigKey) -> String {
        let dashCaseComponents = key.components.map { component in
            convertCamelCaseToDashCase(component)
        }

        let joinedKey = dashCaseComponents.joined(separator: "-")
        return "--\(joinedKey)"
    }
}
