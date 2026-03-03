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

/// A specialized key encoder that transforms configuration keys into environment variable format.
///
/// This encoder converts hierarchical configuration keys into the standard environment variable
/// naming convention used by most systems. It handles camelCase detection, character normalization,
/// and component joining to produce properly formatted environment variable names.
///
/// ## Encoding rules
///
/// The encoder applies these transformations in order:
/// 1. **CamelCase detection**: Inserts underscores at word boundaries (e.g., `serverTimeout` → `server_Timeout`)
/// 2. **Case conversion**: Converts all characters to uppercase
/// 3. **Character normalization**: Replaces non-alphanumeric characters with underscores
/// 4. **Component joining**: Joins all components with underscores
///
/// ## Examples
///
/// ```swift
/// let encoder = EnvironmentKeyEncoder()
///
/// // Basic hierarchical key
/// let key1 = AbsoluteConfigKey(["http", "port"], context: context)
/// encoder.encode(key1) // "HTTP_PORT"
///
/// // CamelCase handling
/// let key2 = AbsoluteConfigKey(["http", "serverTimeout"], context: context)
/// encoder.encode(key2) // "HTTP_SERVER_TIMEOUT"
///
/// // Special character handling
/// let key3 = AbsoluteConfigKey(["http", "user-agent"], context: context)
/// encoder.encode(key3) // "HTTP_USER_AGENT"
/// ```
///
/// ## Character handling
///
/// The encoder preserves only alphanumeric characters (A-Z, a-z, 0-9) in the final environment
/// variable name. It converts all other characters to underscores, ensuring compatibility
/// with environment variable naming conventions across different systems.
@available(Configuration 1.0, *)
internal struct EnvironmentKeyEncoder {}

@available(Configuration 1.0, *)
extension EnvironmentKeyEncoder: ConfigKeyEncoder {
    internal func encode(_ key: AbsoluteConfigKey) -> String {
        let mappedComponents = key.components.map { component in
            // Detect camelCase and replace the word boundary with an underscore.
            // Do that by using a sliding window of two characters, and if the first is
            // lowercase, and the second uppercase, insert the word boundary.
            guard component.count >= 2 else {
                return component
            }
            var component = component
            var index = component.startIndex
            while index < component.index(before: component.endIndex) {
                let first = component[index]
                let nextIndex = component.index(after: index)
                defer {
                    index = nextIndex
                }
                let second = component[nextIndex]
                guard first.isLowercase && second.isUppercase else {
                    continue
                }
                component.insert(contentsOf: "_", at: nextIndex)
            }
            return component
        }
        return
            mappedComponents.map { component in
                component
                    .uppercased()
                    .map { char in
                        char.isLetter || char.isNumber ? String(char) : "_"
                    }
                    .joined()
            }
            .joined(separator: "_")
    }
}
