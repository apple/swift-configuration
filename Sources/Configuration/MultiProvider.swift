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

import Synchronization

/// A provider-like type that combines multiple configuration providers with precedence-based
/// value resolution.
///
/// ``MultiProvider`` allows you to layer multiple configuration sources, where values are resolved
/// by checking providers in order until a non-nil value is found. This enables flexible configuration
/// hierarchies such as command-line arguments overriding environment variables, which in turn override
/// defaults from files.
///
/// ## Value Resolution Strategy
///
/// When a configuration value is requested, ``MultiProvider`` queries nested providers sequentially:
/// 1. Calls the first provider in the list.
/// 2. If the provider returns a non-nil value, that value is returned immediately.
/// 3. If the provider returns nil, the next provider is queried.
/// 4. This continues until a value is found or all providers return nil.
///
/// ```swift
/// let multiProvider = MultiProvider(providers: [
///     commandLineProvider,    // Highest precedence
///     environmentProvider,    // Medium precedence
///     defaultsFileProvider    // Lowest precedence
/// ])
///
/// // Checks command line first, then the environment,
/// // then the defaults file
/// let value = try multiProvider.value(forKey: myKey, type: .string)
/// ```
///
/// ## Execution Patterns
///
/// - **Synchronous and asynchronous access** (`value`, `fetchValue`, `snapshot`): The library calls providers
///   sequentially, returning the first value that is returned from the providers.
/// - **Watching for changes** (`watchValue`, `watchSnapshot`): The library monitors all providers in parallel and
///   returns the first non-nil value from their latest results.
///
/// ## Error Handling
///
/// When any nested provider throws an error, the error is immediately propagated to the caller rather than
/// being ignored. This ensures predictable behavior and prevents silent failures that could mask configuration issues.
internal struct MultiProvider: Sendable {

    /// The underlying storage.
    struct Storage {
        /// The nested providers.
        let providers: [any ConfigProvider]
    }

    /// The underlying storage.
    let storage: Storage

    /// Creates a new multi-provider with the specified nested providers.
    /// - Parameter providers: The nested providers in precedence order (first provider has highest precedence).
    init(providers: [any ConfigProvider]) {
        precondition(!providers.isEmpty, "MultiProvider requires at least one nested provider")
        self.storage = .init(providers: providers)
    }
}

extension MultiProvider: CustomStringConvertible {
    /// A text description of the multi provider.
    var description: String {
        "MultiProvider[of: \(storage.providers.map(\.providerName).joined(separator: ", "))]"
    }
}

/// Represents a point-in-time snapshot of all nested providers within a ``MultiProvider``.
///
/// This snapshot aggregates the individual snapshots from each nested provider, allowing for
/// consistent value resolution across the entire provider hierarchy at a specific moment in time.
struct MultiSnapshot {

    /// The individual snapshots from each nested provider, maintained in precedence order.
    var snapshots: [any ConfigSnapshotProtocol]

    /// Resolves a configuration value by querying nested provider snapshots in precedence order.
    /// - Parameters:
    ///   - key: The configuration key to resolve.
    ///   - type: The expected type of the configuration value.
    /// - Returns: A tuple containing the lookup results from each provider and the final resolved value.
    func multiValue(
        forKey key: AbsoluteConfigKey,
        type: ConfigType
    ) -> ([AccessEvent.ProviderResult], Result<ConfigValue?, any Error>) {
        var results: [AccessEvent.ProviderResult] = []
        for childSnapshot in snapshots {
            let providerName = childSnapshot.providerName
            let lookupResult: LookupResult
            do {
                lookupResult = try childSnapshot.value(
                    forKey: key,
                    type: type
                )
                results.append(.init(providerName: providerName, result: .success(lookupResult)))
            } catch {
                results.append(.init(providerName: providerName, result: .failure(error)))
                // If one provider throws an error, return immediately instead of trying the next one.
                return (results, .failure(error))
            }
            guard let value = lookupResult.value else {
                continue
            }
            return (results, .success(value))
        }
        return (results, .success(nil))
    }
}

extension MultiProvider {

    /// Synchronously resolves a configuration value from nested providers.
    ///
    /// Queries each nested provider sequentially until a non-nil value is found or all providers
    /// have been exhausted. The first provider to return a non-nil value determines the final result.
    ///
    /// - Parameters:
    ///   - key: The configuration key to resolve.
    ///   - type: The expected type of the configuration value.
    /// - Returns: A tuple containing the lookup results from each queried provider and the final resolved value.
    func value(
        forKey key: AbsoluteConfigKey,
        type: ConfigType
    ) -> ([AccessEvent.ProviderResult], Result<ConfigValue?, any Error>) {
        var results: [AccessEvent.ProviderResult] = []
        for childProvider in storage.providers {
            let providerName = childProvider.providerName
            let lookupResult: LookupResult
            do {
                lookupResult = try childProvider.value(
                    forKey: key,
                    type: type
                )
                results.append(.init(providerName: providerName, result: .success(lookupResult)))
            } catch {
                results.append(.init(providerName: providerName, result: .failure(error)))
                // If one provider throws an error, return immediately instead of trying the next one.
                return (results, .failure(error))
            }
            guard let value = lookupResult.value else {
                continue
            }
            return (results, .success(value))
        }
        return (results, .success(nil))
    }

    /// Creates a point-in-time snapshot of all nested providers.
    ///
    /// Collects individual snapshots from each nested provider and combines them into a single
    /// ``MultiSnapshot`` that represents the current state of the entire provider hierarchy.
    /// Use the snapshot for consistent value resolution without the providers changing
    /// state during the lookup process.
    ///
    /// - Returns: A ``MultiSnapshot`` containing snapshots from all nested providers.
    func snapshot() -> MultiSnapshot {
        let snapshots = storage.providers.map { $0.snapshot() }
        return MultiSnapshot(snapshots: snapshots)
    }

    /// Monitors all nested providers for changes and delivers combined snapshot updates.
    ///
    /// Sets up parallel watchers for all nested providers using a "combine latest" strategy.
    /// When any provider emits a new snapshot, the library creates a new ``MultiSnapshot`` containing
    /// the most recent snapshots from all providers and delivers it to the handler.
    ///
    /// ```swift
    /// try await multiProvider.watchSnapshot { snapshots in
    ///     for await snapshot in snapshots {
    ///         // Process the combined snapshot from all providers
    ///         let value = snapshot.multiValue(forKey: myKey, type: .string)
    ///         print("Updated value: \(value)")
    ///     }
    /// }
    /// ```
    ///
    /// - Parameter body: A closure that receives an async sequence of ``MultiSnapshot`` updates.
    /// - Returns: The value returned by the body closure.
    /// - Throws: Any error thrown by the nested providers or the body closure.
    func watchSnapshot<Return>(
        _ body: (ConfigUpdatesAsyncSequence<MultiSnapshot, Never>) async throws -> Return
    ) async throws -> Return {
        let providers = storage.providers
        let sources:
            [@Sendable (
                (ConfigUpdatesAsyncSequence<any ConfigSnapshotProtocol, Never>) async throws -> Void
            ) async throws -> Void] = providers.map { $0.watchSnapshot }
        return try await combineLatestOneOrMore(
            elementType: (any ConfigSnapshotProtocol).self,
            sources: sources,
            updatesHandler: { updateArrays in
                try await body(
                    ConfigUpdatesAsyncSequence(
                        updateArrays
                            .map { array in
                                MultiSnapshot(snapshots: array)
                            }
                    )
                )
            }
        )
    }

    /// Asynchronously resolves a configuration value from nested providers.
    ///
    /// Similar to ``value(forKey:type:)`` but performs asynchronous lookups, allowing providers
    /// to fetch values from remote sources or perform other async operations. The library queries providers
    /// sequentially in precedence order.
    ///
    /// - Parameters:
    ///   - key: The configuration key to resolve.
    ///   - type: The expected type of the configuration value.
    /// - Returns: A tuple containing the lookup results from each queried provider and the final resolved value.
    func fetchValue(
        forKey key: AbsoluteConfigKey,
        type: ConfigType
    ) async -> ([AccessEvent.ProviderResult], Result<ConfigValue?, any Error>) {
        var results: [AccessEvent.ProviderResult] = []
        for childProvider in storage.providers {
            let providerName = childProvider.providerName
            let lookupResult: LookupResult
            do {
                lookupResult = try await childProvider.fetchValue(
                    forKey: key,
                    type: type
                )
                results.append(.init(providerName: providerName, result: .success(lookupResult)))
            } catch {
                results.append(.init(providerName: providerName, result: .failure(error)))
                // If one provider throws an error, return immediately instead of trying the next one.
                return (results, .failure(error))
            }
            guard let value = lookupResult.value else {
                continue
            }
            return (results, .success(value))
        }
        return (results, .success(nil))
    }

    /// Monitors a specific configuration value across all nested providers for changes.
    ///
    /// Sets up parallel watchers for the specified key across all nested providers. Uses a "combine latest"
    /// strategy to deliver updates whenever any provider's value for this key changes. The resolved value
    /// follows the same precedence rules as synchronous access.
    ///
    /// ```swift
    /// try await multiProvider.watchValue(forKey: myKey, type: .string) { updates in
    ///     for await (providerResults, finalValue) in updates {
    ///         switch finalValue {
    ///         case .success(let value):
    ///             print("Configuration updated: \(value ?? "nil")")
    ///         case .failure(let error):
    ///             print("Configuration error: \(error)")
    ///         }
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - key: The configuration key to monitor.
    ///   - type: The expected type of the configuration value.
    ///   - updatesHandler: A closure that receives an async sequence of combined updates from all providers.
    /// - Throws: Any error thrown by the nested providers or the handler closure.
    /// - Returns: The value returned by the handler.
    func watchValue<Return>(
        forKey key: AbsoluteConfigKey,
        type: ConfigType,
        updatesHandler: (
            ConfigUpdatesAsyncSequence<([AccessEvent.ProviderResult], Result<ConfigValue?, any Error>), Never>
        ) async throws -> Return
    ) async throws -> Return {
        let providers = storage.providers
        let providerNames = providers.map(\.providerName)
        let sources:
            [@Sendable (
                (
                    ConfigUpdatesAsyncSequence<Result<LookupResult, any Error>, Never>
                ) async throws -> Void
            ) async throws -> Void] = providers.map { provider in
                { handler in
                    _ = try await provider.watchValue(forKey: key, type: type, updatesHandler: handler)
                }
            }
        return try await combineLatestOneOrMore(
            elementType: Result<LookupResult, any Error>.self,
            sources: sources,
            updatesHandler: { updateArrays in
                try await updatesHandler(
                    ConfigUpdatesAsyncSequence(
                        updateArrays
                            .map { array in
                                var results: [AccessEvent.ProviderResult] = []
                                for (providerIndex, lookupResult) in array.enumerated() {
                                    let providerName = providerNames[providerIndex]
                                    results.append(.init(providerName: providerName, result: lookupResult))
                                    switch lookupResult {
                                    case .success(let value) where value.value == nil:
                                        // Got a success + nil from a nested provider, keep iterating.
                                        continue
                                    default:
                                        // Got a success + non-nil or an error from a nested provider, propagate that up.
                                        return (results, lookupResult.map { $0.value })
                                    }
                                }
                                // If all nested results were success + nil, return the same.
                                return (results, .success(nil))
                            }
                    )
                )
            }
        )
    }
}
