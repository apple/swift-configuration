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
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// A configuration provider that stores mutable values in memory.
///
/// Unlike ``InMemoryProvider``, this provider allows configuration values to be
/// modified after initialization. It maintains thread-safe access to values and
/// supports real-time notifications when values change, making it ideal for
/// dynamic configuration scenarios.
///
/// ## Change notifications
///
/// The provider supports watching for configuration changes through the standard
/// ``ConfigProvider`` watching methods. When a value changes, all active watchers
/// are automatically notified with the new value.
///
/// ## Use cases
///
/// The mutable in-memory provider is particularly useful for:
/// - **Dynamic configuration**: Values that change during application runtime
/// - **Configuration bridges**: Adapting external configuration systems that push updates
/// - **Testing scenarios**: Simulating configuration changes in unit tests
/// - **Feature flags**: Runtime toggles that can be modified programmatically
///
/// ## Performance characteristics
///
/// This provider offers O(1) lookup time with minimal synchronization overhead.
/// Value updates are atomic and efficiently notify only the relevant watchers.
///
/// ## Usage
///
/// ```swift
/// // Create provider with initial values
/// let provider = MutableInMemoryProvider(initialValues: [
///     "feature.enabled": true,
///     "api.timeout": 30.0,
///     "database.host": "localhost"
/// ])
///
/// let config = ConfigReader(provider: provider)
///
/// // Read initial values
/// let isEnabled = config.bool(forKey: "feature.enabled") // true
///
/// // Update values dynamically
/// provider.setValue(false, forKey: "feature.enabled")
///
/// // Read updated values
/// let stillEnabled = config.bool(forKey: "feature.enabled") // false
/// ```
///
/// To learn more about the in-memory providers, check out <doc:Using-in-memory-providers>.
@available(Configuration 1.0, *)
public final class MutableInMemoryProvider: Sendable {

    /// The name of this instance of the provider.
    ///
    /// The assumption is that there might be multiple instances in a given process.
    private let name: String?

    /// The internal storage of the provider's state.
    struct Storage {

        /// The current snapshot.
        var snapshot: Snapshot

        /// The active watchers of values, keyed by config key.
        var valueWatchers: [AbsoluteConfigKey: [UUID: AsyncStream<ConfigValue?>.Continuation]]

        /// The active watchers of snapshots.
        var snapshotWatchers: [UUID: AsyncStream<Snapshot>.Continuation]
    }

    /// A snapshot of the internal state.
    struct Snapshot: Sendable {
        /// The name of the provider.
        var providerName: String

        /// The current config values.
        var values: [AbsoluteConfigKey: ConfigValue]
    }

    /// The internal state protected by a mutex.
    private let storage: Mutex<Storage>

    /// Creates a new mutable in-memory provider with the specified initial values.
    ///
    /// This initializer takes a dictionary of absolute configuration keys mapped to
    /// their initial values. The provider can be modified after creation using
    /// ``setValue(_:forKey:)``, ``setValues(_:)``, or ``withValues(_:)``.
    ///
    /// ```swift
    /// let key1 = AbsoluteConfigKey(["database", "host"], context: [:])
    /// let key2 = AbsoluteConfigKey(["database", "port"], context: [:])
    ///
    /// let provider = MutableInMemoryProvider(
    ///     name: "dynamic-config",
    ///     initialValues: [
    ///         key1: "localhost",
    ///         key2: 5432
    ///     ]
    /// )
    ///
    /// // Later, update values dynamically
    /// provider.setValue("production-db", forKey: key1)
    /// ```
    ///
    /// - Parameters:
    ///   - name: An optional name for the provider, used in debugging and logging.
    ///   - initialValues: A dictionary mapping absolute configuration keys to their initial values.
    public init(
        name: String? = nil,
        initialValues: [AbsoluteConfigKey: ConfigValue]
    ) {
        self.name = name
        self.storage = .init(
            .init(
                snapshot: .init(
                    providerName: providerNameFromName(name),
                    values: initialValues
                ),
                valueWatchers: [:],
                snapshotWatchers: [:]
            )
        )
    }
}

@available(Configuration 1.0, *)
extension MutableInMemoryProvider {

    /// Updates the stored value for the specified configuration key.
    ///
    /// This method atomically updates the value and notifies all active watchers
    /// of the change. If the new value is the same as the existing value, no
    /// notification is sent.
    ///
    /// ```swift
    /// let provider = MutableInMemoryProvider(initialValues: [:])
    /// let key = AbsoluteConfigKey(["api", "enabled"], context: [:])
    ///
    /// // Set a new value
    /// provider.setValue(true, forKey: key)
    ///
    /// // Remove a value
    /// provider.setValue(nil, forKey: key)
    /// ```
    ///
    /// - Parameters:
    ///   - value: The new configuration value, or `nil` to remove the value entirely.
    ///   - key: The absolute configuration key to update.
    public func setValue(_ value: ConfigValue?, forKey key: AbsoluteConfigKey) {
        var valueContinuationsToNotify: [UUID: AsyncStream<ConfigValue?>.Continuation]?
        var snapshotContinuationsToNotify: ([UUID: AsyncStream<Snapshot>.Continuation], Snapshot)?
        storage.withLock { storage in
            let oldValue = storage.snapshot.values[key]
            guard oldValue != value else {
                return
            }
            storage.snapshot.values[key] = value
            valueContinuationsToNotify = storage.valueWatchers[key]
            let snapshotWatchers = storage.snapshotWatchers
            if !snapshotWatchers.isEmpty {
                snapshotContinuationsToNotify = (snapshotWatchers, storage.snapshot)
            }
        }
        if let valueContinuationsToNotify {
            for (_, continuation) in valueContinuationsToNotify {
                continuation.yield(value)
            }
        }
        if let (continuations, snapshot) = snapshotContinuationsToNotify {
            for (_, continuation) in continuations {
                continuation.yield(snapshot)
            }
        }
    }

    /// Updates the stored values for multiple configuration keys at once.
    ///
    /// This method atomically applies all the updates, so a snapshot never contains some
    /// of the updates without the others. Watchers of a changed key receive its new value
    /// once. If any value changed, snapshot watchers receive one snapshot that contains all
    /// the updates. If a new value is the same as the existing value, no notification is
    /// sent for that key. Keys not included in `values` keep their current values.
    ///
    /// ```swift
    /// let provider = MutableInMemoryProvider(initialValues: [:])
    ///
    /// provider.setValues([
    ///     "database.host": "db-a.example.com",
    ///     "database.port": 5433,
    ///     "database.timeout": nil, // Removes the value
    /// ])
    /// ```
    ///
    /// - Parameter values: A dictionary that maps configuration keys to their new values,
    ///   or to `nil` to remove a value entirely.
    public func setValues(_ values: [AbsoluteConfigKey: ConfigValue?]) {
        withValues { storedValues in
            for (key, value) in values {
                storedValues[key] = value
            }
        }
    }

    /// Reads and updates the stored values in a single atomic operation.
    ///
    /// The body runs while the provider holds its lock, so no other reads or updates happen
    /// until it finishes. It edits the stored values in place: if the body throws, the changes
    /// it made before the error are kept. When the body returns or throws, watchers of changed
    /// keys receive their new values, and snapshot watchers receive one snapshot that contains
    /// all the changes.
    ///
    /// Don't call the provider, or a ``ConfigReader`` that reads from it, from inside the
    /// body. The lock isn't recursive, so the call crashes or deadlocks.
    ///
    /// ```swift
    /// provider.withValues { values in
    ///     if values["database.host"] == "db-a.example.com" {
    ///         values["database.host"] = "db-b.example.com"
    ///         values["database.port"] = 6432
    ///     }
    /// }
    /// ```
    ///
    /// - Parameter body: A closure that reads and modifies the stored values.
    /// - Returns: The value that `body` returns.
    /// - Throws: Rethrows any error that `body` throws.
    public func withValues<Return: ~Copyable, Failure: Error>(
        _ body: (inout [AbsoluteConfigKey: ConfigValue]) throws(Failure) -> Return
    ) throws(Failure) -> Return {
        var valueUpdatesToNotify: [(ConfigValue?, [UUID: AsyncStream<ConfigValue?>.Continuation])] = []
        var snapshotContinuationsToNotify: ([UUID: AsyncStream<Snapshot>.Continuation], Snapshot)?
        // Notify watchers outside the lock, also when the body throws.
        defer {
            for (value, continuations) in valueUpdatesToNotify {
                for (_, continuation) in continuations {
                    continuation.yield(value)
                }
            }
            if let (continuations, snapshot) = snapshotContinuationsToNotify {
                for (_, continuation) in continuations {
                    continuation.yield(snapshot)
                }
            }
        }
        return try storage.withLock { storage throws(Failure) in
            // Remember only what change detection needs. Holding the whole dictionary makes
            // the body's first write copy it, so only do that when snapshot watchers need it.
            var watchedValuesBefore: [(AbsoluteConfigKey, ConfigValue?)] = []
            for (key, continuations) in storage.valueWatchers where !continuations.isEmpty {
                watchedValuesBefore.append((key, storage.snapshot.values[key]))
            }
            let valuesBefore = storage.snapshotWatchers.isEmpty ? nil : storage.snapshot.values
            // A body that throws keeps its changes, so collect them on that path too.
            defer {
                for (key, oldValue) in watchedValuesBefore {
                    let newValue = storage.snapshot.values[key]
                    if newValue != oldValue, let continuations = storage.valueWatchers[key] {
                        valueUpdatesToNotify.append((newValue, continuations))
                    }
                }
                if let valuesBefore, valuesBefore != storage.snapshot.values {
                    snapshotContinuationsToNotify = (storage.snapshotWatchers, storage.snapshot)
                }
            }
            return try body(&storage.snapshot.values)
        }
    }
}

@available(Configuration 1.0, *)
extension MutableInMemoryProvider: CustomStringConvertible {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public var description: String {
        storage.withLock { storage in
            let values = storage.snapshot.values
            let watcherCount = storage.watcherCount()
            return
                "MutableInMemoryProvider[\(name.map { "\($0), " } ?? "")\(watcherCount) watchers, \(values.count) values]"
        }
    }
}

@available(Configuration 1.0, *)
extension MutableInMemoryProvider: CustomDebugStringConvertible {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public var debugDescription: String {
        storage.withLock { storage in
            let values = storage.snapshot.values
            let watcherCount = storage.watcherCount()
            let prettyValues =
                values
                .sorted { $0.key < $1.key }
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: ", ")
            return
                "MutableInMemoryProvider[\(name.map { "\($0), " } ?? "")\(watcherCount) watchers, \(values.count) values: \(prettyValues)]"
        }
    }
}

@available(Configuration 1.0, *)
extension MutableInMemoryProvider.Storage {
    /// Returns the number of current watchers, summing value and snapshot watchers.
    func watcherCount() -> Int {
        valueWatchers.values.reduce(0, { $0 + $1.count }) + snapshotWatchers.count
    }
}

@available(Configuration 1.0, *)
extension MutableInMemoryProvider {
    /// Adds a continuation that gets notified of new values for the provided key.
    /// - Parameters:
    ///   - continuation: The stream continuation for sending value updates.
    ///   - id: The unique identifier of the continuation.
    ///   - key: The config key to watch for updates.
    private func addValueContinuation(
        _ continuation: AsyncStream<ConfigValue?>.Continuation,
        id: UUID,
        forKey key: AbsoluteConfigKey
    ) {
        storage.withLock { storage in
            storage.valueWatchers[key, default: [:]][id] = continuation
            continuation.yield(storage.snapshot.values[key])
        }
    }

    /// Removes the stored continuation for the provided identifier and config key.
    /// - Parameters:
    ///   - id: The unique identifier of the continuation.
    ///   - key: The config key.
    private func removeValueContinuation(id: UUID, forKey key: AbsoluteConfigKey) {
        storage.withLock { storage in
            storage.valueWatchers[key]?[id] = nil
        }
    }

    private func addSnapshotContinuation(
        _ continuation: AsyncStream<Snapshot>.Continuation,
        id: UUID
    ) {
        storage.withLock { storage in
            storage.snapshotWatchers[id] = continuation
            continuation.yield(storage.snapshot)
        }
    }

    private func removeSnapshotContinuation(id: UUID) {
        storage.withLock { storage in
            storage.snapshotWatchers[id] = nil
        }
    }

    static func parseValue(
        _ value: ConfigValue?,
        key: AbsoluteConfigKey,
        type: ConfigType
    ) throws -> LookupResult {
        try withConfigValueLookup(encodedKey: key.description) {
            guard let value else {
                return nil
            }
            guard value.content.type == type else {
                throw ConfigError.configValueNotConvertible(name: key.description, type: type)
            }
            return value
        }
    }
}

@available(Configuration 1.0, *)
extension MutableInMemoryProvider.Snapshot: ConfigSnapshot {
    func value(forKey key: AbsoluteConfigKey, type: ConfigType) throws -> LookupResult {
        try MutableInMemoryProvider.parseValue(
            values[key],
            key: key,
            type: type
        )
    }
}

/// Creates the name of the provider, taking the user-provided name into account.
/// - Parameter name: The user-provided name used for disambiguation.
/// - Returns: The full provider name.
private func providerNameFromName(_ name: String?) -> String {
    "MutableInMemoryProvider\(name.map { "[\($0)]" } ?? "")"
}

@available(Configuration 1.0, *)
extension MutableInMemoryProvider: ConfigProvider {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public var providerName: String {
        providerNameFromName(name)
    }

    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public func value(
        forKey key: AbsoluteConfigKey,
        type: ConfigType
    ) throws -> LookupResult {
        try storage.withLock { storage in
            try storage.snapshot.value(forKey: key, type: type)
        }
    }

    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public func fetchValue(
        forKey key: AbsoluteConfigKey,
        type: ConfigType
    ) async throws -> LookupResult {
        try value(forKey: key, type: type)
    }

    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public func watchValue<Return: ~Copyable>(
        forKey key: AbsoluteConfigKey,
        type: ConfigType,
        updatesHandler: (
            _ updates: ConfigUpdatesAsyncSequence<Result<LookupResult, any Error>, Never>
        ) async throws -> Return
    ) async throws -> Return {
        let (stream, continuation) = AsyncStream<ConfigValue?>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let id = UUID()
        addValueContinuation(continuation, id: id, forKey: key)
        defer {
            removeValueContinuation(id: id, forKey: key)
        }
        let encodedKey = key.description
        return try await updatesHandler(
            ConfigUpdatesAsyncSequence(
                stream.map { (value: ConfigValue?) -> Result<LookupResult, any Error> in
                    guard let value else {
                        return .success(.init(encodedKey: encodedKey, value: nil))
                    }
                    do {
                        guard value.content.type == type else {
                            throw ConfigError.configValueNotConvertible(name: key.description, type: type)
                        }
                        return .success(.init(encodedKey: encodedKey, value: value))
                    } catch {
                        return .failure(error)
                    }
                }
            )
        )
    }

    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public func snapshot() -> any ConfigSnapshot {
        storage.withLock { $0.snapshot }
    }

    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public func watchSnapshot<Return: ~Copyable>(
        updatesHandler: (_ updates: ConfigUpdatesAsyncSequence<any ConfigSnapshot, Never>) async throws -> Return
    ) async throws -> Return {
        let (stream, continuation) = AsyncStream<Snapshot>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let id = UUID()
        addSnapshotContinuation(continuation, id: id)
        defer {
            removeSnapshotContinuation(id: id)
        }
        return try await updatesHandler(.init(stream.map { $0 }))
    }
}
