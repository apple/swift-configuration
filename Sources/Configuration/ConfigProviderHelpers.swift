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

@available(Configuration 1.0, *)
extension ConfigProvider {

    /// Implements `watchValue` by getting the current value and emitting it immediately.
    ///
    /// Use this convenience method for providers that store static values in memory.
    /// The method creates an async sequence that emits the current value once and
    /// then remains idle, since the values don't change over time.
    ///
    /// This is the most common implementation for simple providers like environment
    /// variables or JSON file providers.
    ///
    /// The following example shows using this convenience function:
    ///
    /// ```swift
    /// func watchValue(
    ///     forKey: AbsoluteConfigKey,
    ///     type: ConfigType,
    ///     updatesHandler: (ConfigUpdatesAsyncSequence<Result<LookupResult, any Error>, Never>) async throws -> Void
    /// ) async throws {
    ///     try await watchValueFromValue(forKey: key, type: type, updatesHandler: updatesHandler)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - key: The configuration key to monitor.
    ///   - type: The expected configuration value type.
    ///   - updatesHandler: The closure that processes the async sequence of value updates.
    /// - Returns: The value returned by the handler closure.
    /// - Throws: Provider-specific errors or errors thrown by the handler.
    public func watchValueFromValue<Return>(
        forKey key: AbsoluteConfigKey,
        type: ConfigType,
        updatesHandler: (
            ConfigUpdatesAsyncSequence<Result<LookupResult, any Error>, Never>
        ) async throws -> Return
    ) async throws -> Return {
        let (stream, continuation) = AsyncStream<Result<LookupResult, any Error>>
            .makeStream(bufferingPolicy: .bufferingNewest(1))
        let initialValue: Result<LookupResult, any Error>
        do {
            initialValue = .success(try value(forKey: key, type: type))
        } catch {
            initialValue = .failure(error)
        }
        continuation.yield(initialValue)
        return try await updatesHandler(.init(stream))
    }

    /// Implements `watchSnapshot` by getting the current snapshot and emitting it immediately.
    ///
    /// Use this convenience method for providers whose state doesn't change over time.
    /// The method creates an async sequence that emits the current snapshot once and
    /// then remains idle.
    ///
    /// This is suitable for providers that load configuration from static sources
    /// like files or environment variables that don't change during application runtime.
    ///
    /// The following example shows using this convenience function:
    ///
    /// ```swift
    /// func watchSnapshot(
    ///     updatesHandler: (ConfigUpdatesAsyncSequence<any ConfigSnapshotProtocol, Never>) async throws -> Void
    /// ) async throws {
    ///     try await watchSnapshotFromSnapshot(updatesHandler)
    /// }
    /// ```
    ///
    /// - Parameter updatesHandler: The closure that processes the async sequence of snapshot updates.
    /// - Returns: The value returned by the handler closure.
    /// - Throws: Provider-specific errors or errors thrown by the handler.
    public func watchSnapshotFromSnapshot<Return>(
        updatesHandler: (ConfigUpdatesAsyncSequence<any ConfigSnapshotProtocol, Never>) async throws -> Return
    ) async throws -> Return {
        let (stream, continuation) = AsyncStream<any ConfigSnapshotProtocol>
            .makeStream(bufferingPolicy: .bufferingNewest(1))
        let initialValue = snapshot()
        continuation.yield(initialValue)
        return try await updatesHandler(.init(stream))
    }
}

/// Creates a lookup result from a configuration value retrieval operation.
///
/// This convenience function simplifies provider implementations by handling the
/// common pattern of executing a closure that returns an optional configuration
/// value and wraps the result in a ``LookupResult``.
///
/// The following example shows using this convenience function:
///
/// ```swift
/// func value(forKey key: AbsoluteConfigKey, type: ConfigType) throws -> LookupResult {
///     let encodedKey = encodeKey(key)
///     return withConfigValueLookup(encodedKey: encodedKey) {
///         // Look up the value in your data source
///         return findValue(forKey: encodedKey, type: type)
///     }
/// }
/// ```
///
/// - Parameters:
///   - encodedKey: The provider-specific encoding of the configuration key.
///   - work: A closure that performs the value lookup and returns the result.
/// - Returns: A lookup result containing the encoded key and the value from the closure.
/// - Throws: Rethrows any errors thrown by the provided closure.
@available(Configuration 1.0, *)
package func withConfigValueLookup<Failure: Error>(
    encodedKey: String,
    work: () throws(Failure) -> ConfigValue?
) throws(Failure) -> LookupResult {
    let value = try work()
    return .init(encodedKey: encodedKey, value: value)
}

/// Creates a lookup result from an asynchronous configuration value retrieval operation.
///
/// This convenience function simplifies provider implementations by handling the
/// common pattern of executing an async closure that returns an optional configuration
/// value and wraps the result in a ``LookupResult``.
///
/// The following example shows using this convenience function:
///
/// ```swift
/// func fetchValue(forKey: AbsoluteConfigKey, type: ConfigType) async throws -> LookupResult {
///     let encodedKey = encodeKey(key)
///     return await withConfigValueLookup(encodedKey: encodedKey) {
///         // Asynchronously fetch the value from a remote source
///         try await fetchRemoteValue(forKey: encodedKey, type: type)
///     }
/// }
/// ```
///
/// - Parameters:
///   - encodedKey: The provider-specific encoding of the configuration key.
///   - work: An async closure that performs the value lookup and returns the result.
/// - Returns: A lookup result containing the encoded key and the value from the closure.
/// - Throws: Rethrows any errors thrown by the provided closure.
@available(Configuration 1.0, *)
package func withConfigValueLookup<Failure: Error>(
    encodedKey: String,
    work: () async throws(Failure) -> ConfigValue?
) async throws(Failure) -> LookupResult {
    let value = try await work()
    return .init(encodedKey: encodedKey, value: value)
}
