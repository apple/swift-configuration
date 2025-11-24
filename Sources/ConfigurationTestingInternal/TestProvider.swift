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

package import Configuration
import Testing

/// A configurable test provider for unit testing configuration scenarios.
///
/// ``TestProvider`` allows you to create a configuration provider with predefined
/// responses for specific keys, including the ability to simulate errors. This is
/// particularly useful for testing error handling and edge cases in configuration
/// consumers.
///
/// ## Usage
///
/// Create a test provider with specific values and error conditions:
///
/// ```swift
/// let provider = TestProvider(values: [
///     "valid.key": .success("test"),
///     "error.key": .failure(TestProvider.TestError())
/// ])
/// ```
@available(Configuration 1.0, *)
package struct TestProvider: Sendable {

    /// A generic error type for testing error scenarios.
    package struct TestError: Error {
        /// Creates a new test error.
        package init() {}
    }

    /// The predefined responses for configuration keys.
    ///
    /// Maps absolute configuration keys to either successful values or errors
    /// that should be thrown when those keys are requested.
    private let values: [AbsoluteConfigKey: Result<ConfigValue, any Error>]

    /// Creates a new test provider with predefined key-value mappings.
    /// - Parameter values: A dictionary mapping keys to their expected results.
    package init(values: [AbsoluteConfigKey: Result<ConfigValue, any Error>]) {
        self.values = values
    }
}

@available(Configuration 1.0, *)
extension TestProvider: ConfigProvider, ConfigSnapshot {
    package var providerName: String {
        "TestProvider"
    }

    package func value(
        forKey key: AbsoluteConfigKey,
        type: ConfigType
    ) throws -> LookupResult {
        try withConfigValueLookup(encodedKey: key.description) {
            guard let value = try values[key]?.get() else {
                return nil
            }
            guard value.content.type == type else {
                throw ConfigError.configValueNotConvertible(name: key.description, type: type)
            }
            return value
        }
    }

    package func snapshot() -> any ConfigSnapshot {
        self
    }

    package func watchSnapshot<Return>(
        updatesHandler: (_ updates: ConfigUpdatesAsyncSequence<any ConfigSnapshot, Never>) async throws -> Return
    )
        async throws -> Return
    {
        try await watchSnapshotFromSnapshot(updatesHandler: updatesHandler)
    }

    package func fetchValue(
        forKey key: AbsoluteConfigKey,
        type: ConfigType
    ) async throws -> LookupResult {
        try value(forKey: key, type: type)
    }

    package func watchValue<Return>(
        forKey key: AbsoluteConfigKey,
        type: ConfigType,
        updatesHandler handler: (
            _ updates: ConfigUpdatesAsyncSequence<Result<LookupResult, any Error>, Never>
        ) async throws -> Return
    ) async throws -> Return {
        try await watchValueFromValue(forKey: key, type: type, updatesHandler: handler)
    }
}
