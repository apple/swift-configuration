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

#if ReloadingSupport

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import ServiceLifecycle
import Logging
import Metrics
import Synchronization
import AsyncAlgorithms
import SystemPackage

/// A generic common implementation of file-based reloading for configuration providers.
///
/// This internal type handles all the common reloading logic, state management,
/// and service lifecycle for reloading file-based providers. It allows different provider types
/// (JSON, YAML, and so on) to reuse the same logic while providing their own format-specific deserialization.
internal final class ReloadingFileProviderCore<SnapshotType: ConfigSnapshotProtocol>: Sendable {

    /// The internal storage structure for the provider state.
    private struct Storage {

        /// The current configuration snapshot.
        var snapshot: SnapshotType

        /// Last modified timestamp of the resolved file.
        var lastModifiedTimestamp: Date

        /// The resolved real file path.
        var realFilePath: FilePath

        /// Active watchers for individual configuration values, keyed by encoded key.
        var valueWatchers: [AbsoluteConfigKey: [UUID: AsyncStream<Result<LookupResult, any Error>>.Continuation]]

        /// Active watchers for configuration snapshots.
        var snapshotWatchers: [UUID: AsyncStream<SnapshotType>.Continuation]

        /// Returns the total number of active watchers.
        var totalWatcherCount: Int {
            let valueWatcherCount = valueWatchers.values.map(\.count).reduce(0, +)
            let snapshotWatcherCount = snapshotWatchers.count
            return valueWatcherCount + snapshotWatcherCount
        }
    }

    /// Internal provider storage.
    private let storage: Mutex<Storage>

    /// The file system interface for reading files and timestamps.
    private let fileSystem: any CommonProviderFileSystem

    /// The original unresolved file path provided by the user, may contain symlinks.
    private let filePath: FilePath

    /// The interval between polling checks.
    private let pollInterval: Duration

    /// The human-readable name of the provider.
    internal let providerName: String

    /// The logger for this provider instance.
    private let logger: Logger

    /// The metrics collector for this provider instance.
    private let metrics: ReloadingFileProviderMetrics

    /// The closure that creates a new snapshot from file data.
    private let createSnapshot: @Sendable (Data) async throws -> SnapshotType

    /// Creates a new reloading file provider core.
    ///
    /// This initializer performs the initial file load and snapshot creation,
    /// resolves any symlinks, and sets up the internal storage.
    ///
    /// - Parameters:
    ///   - filePath: The path to the configuration file to monitor.
    ///   - pollInterval: The interval between timestamp checks.
    ///   - providerName: The human-readable name of the provider.
    ///   - fileSystem: The file system to use.
    ///   - logger: The logger instance, or nil to create a default one.
    ///   - metrics: The metrics factory, or nil to use a no-op implementation.
    ///   - createSnapshot: A closure that creates a snapshot from file data.
    /// - Throws: If the initial file load or snapshot creation fails.
    internal init(
        filePath: FilePath,
        pollInterval: Duration,
        providerName: String,
        fileSystem: any CommonProviderFileSystem,
        logger: Logger?,
        metrics: (any MetricsFactory)?,
        createSnapshot: @Sendable @escaping (Data) async throws -> SnapshotType
    ) async throws {
        self.filePath = filePath
        self.pollInterval = pollInterval
        self.providerName = providerName
        self.fileSystem = fileSystem
        self.createSnapshot = createSnapshot

        // Set up the logger with metadata
        var logger = logger ?? Logger(label: providerName)
        logger[metadataKey: "\(providerName).filePath"] = .string(filePath.lastComponent?.string ?? "<nil>")
        logger[metadataKey: "\(providerName).pollInterval.seconds"] = .string(
            pollInterval.components.seconds.description
        )
        self.logger = logger

        // Set up metrics
        self.metrics = ReloadingFileProviderMetrics(
            factory: metrics ?? NOOPMetricsHandler.instance,
            providerName: providerName
        )

        // Perform initial load
        logger.debug("Performing initial file load")
        let realPath = try await fileSystem.resolveSymlinks(atPath: filePath)
        let data = try await fileSystem.fileContents(atPath: realPath)
        let initialSnapshot = try await createSnapshot(data)
        let timestamp = try await fileSystem.lastModifiedTimestamp(atPath: realPath)

        // Initialize storage
        self.storage = .init(
            .init(
                snapshot: initialSnapshot,
                lastModifiedTimestamp: timestamp,
                realFilePath: realPath,
                valueWatchers: [:],
                snapshotWatchers: [:]
            )
        )

        // Update initial metrics
        self.metrics.fileSize.record(data.count)

        logger.debug(
            "Successfully initialized reloading file provider core",
            metadata: [
                "\(providerName).realFilePath": .string(realPath.string),
                "\(providerName).initialTimestamp": .stringConvertible(timestamp.formatted(.iso8601)),
                "\(providerName).fileSize": .stringConvertible(data.count),
            ]
        )
    }

    /// Checks if the file has changed and reloads it if necessary.
    /// - Throws: File system errors or snapshot creation errors.
    /// - Parameter logger: The logger to use during the reload.
    internal func reloadIfNeeded(logger: Logger) async throws {
        logger.debug("reloadIfNeeded started")
        defer {
            logger.debug("reloadIfNeeded finished")
        }

        let candidateRealPath = try await fileSystem.resolveSymlinks(atPath: filePath)
        let candidateTimestamp = try await fileSystem.lastModifiedTimestamp(atPath: candidateRealPath)

        guard
            let (originalTimestamp, originalRealPath) =
                storage
                .withLock({ storage -> (Date, FilePath)? in
                    let originalTimestamp = storage.lastModifiedTimestamp
                    let originalRealPath = storage.realFilePath

                    // Check if either the real path or timestamp has changed
                    guard originalRealPath != candidateRealPath || originalTimestamp != candidateTimestamp else {
                        logger.debug(
                            "File path and timestamp unchanged, no reload needed",
                            metadata: [
                                "\(providerName).timestamp": .stringConvertible(originalTimestamp.formatted(.iso8601)),
                                "\(providerName).realPath": .string(originalRealPath.string),
                            ]
                        )
                        return nil
                    }
                    return (originalTimestamp, originalRealPath)
                })
        else {
            // No changes detected.
            return
        }

        logger.debug(
            "File path or timestamp changed, reloading...",
            metadata: [
                "\(providerName).originalTimestamp": .stringConvertible(originalTimestamp.formatted(.iso8601)),
                "\(providerName).candidateTimestamp": .stringConvertible(candidateTimestamp.formatted(.iso8601)),
                "\(providerName).originalRealPath": .string(originalRealPath.string),
                "\(providerName).candidateRealPath": .string(candidateRealPath.string),
            ]
        )

        // Load new data outside the lock
        let data = try await fileSystem.fileContents(atPath: candidateRealPath)
        let newSnapshot = try await createSnapshot(data)

        typealias ValueWatchers = [(
            AbsoluteConfigKey,
            Result<LookupResult, any Error>,
            [AsyncStream<Result<LookupResult, any Error>>.Continuation]
        )]
        typealias SnapshotWatchers = (SnapshotType, [AsyncStream<SnapshotType>.Continuation])
        guard
            let (valueWatchersToNotify, snapshotWatchersToNotify) =
                storage
                .withLock({ storage -> (ValueWatchers, SnapshotWatchers)? in

                    // Check if we lost the race with another caller
                    if storage.lastModifiedTimestamp != originalTimestamp || storage.realFilePath != originalRealPath {
                        return nil
                    }

                    // Update storage with new data
                    let oldSnapshot = storage.snapshot
                    storage.snapshot = newSnapshot
                    storage.lastModifiedTimestamp = candidateTimestamp
                    storage.realFilePath = candidateRealPath

                    logger.debug(
                        "Successfully reloaded file",
                        metadata: [
                            "\(providerName).timestamp": .stringConvertible(candidateTimestamp.formatted(.iso8601)),
                            "\(providerName).fileSize": .stringConvertible(data.count),
                            "\(providerName).realPath": .string(candidateRealPath.string),
                        ]
                    )

                    // Update metrics
                    metrics.reloadCounter.increment(by: 1)
                    metrics.fileSize.record(data.count)
                    metrics.watcherCount.record(storage.totalWatcherCount)

                    // Collect watchers to potentially notify outside the lock
                    let valueWatchers = storage.valueWatchers.compactMap {
                        (key, watchers) -> (
                            AbsoluteConfigKey,
                            Result<LookupResult, any Error>,
                            [AsyncStream<Result<LookupResult, any Error>>.Continuation]
                        )? in
                        guard !watchers.isEmpty else { return nil }

                        // Get old and new values for this key
                        let oldValue = Result { try oldSnapshot.value(forKey: key, type: .string) }
                        let newValue = Result { try newSnapshot.value(forKey: key, type: .string) }

                        let didChange =
                            switch (oldValue, newValue) {
                            case (.success(let lhs), .success(let rhs)):
                                lhs != rhs
                            case (.failure, .failure):
                                false
                            default:
                                true
                            }

                        // Only notify if the value changed
                        guard didChange else {
                            return nil
                        }
                        return (key, newValue, Array(watchers.values))
                    }

                    let snapshotWatchers = (newSnapshot, Array(storage.snapshotWatchers.values))
                    return (valueWatchers, snapshotWatchers)
                })
        else {
            logger.debug("Lost race with another caller, not modifying internal state")
            return
        }

        // Notify watchers outside the lock
        let totalWatchers = valueWatchersToNotify.map { $0.2.count }.reduce(0, +) + snapshotWatchersToNotify.1.count
        guard totalWatchers > 0 else {
            logger.debug("No watchers to notify")
            return
        }

        // Notify value watchers
        for (_, valueUpdate, watchers) in valueWatchersToNotify {
            for watcher in watchers {
                watcher.yield(valueUpdate)
            }
        }

        // Notify snapshot watchers
        for watcher in snapshotWatchersToNotify.1 {
            watcher.yield(snapshotWatchersToNotify.0)
        }

        logger.debug(
            "Notified watchers of file changes",
            metadata: [
                "\(providerName).valueWatcherKeys": .array(valueWatchersToNotify.map { .string($0.0.description) }),
                "\(providerName).snapshotWatcherCount": .stringConvertible(snapshotWatchersToNotify.1.count),
                "\(providerName).totalWatcherCount": .stringConvertible(totalWatchers),
            ]
        )
    }
}

extension ReloadingFileProviderCore: Service {
    internal func run() async throws {
        logger.debug("File polling starting")
        defer {
            logger.debug("File polling stopping")
        }

        var counter = 1
        for try await _ in AsyncTimerSequence(interval: pollInterval, clock: .continuous).cancelOnGracefulShutdown() {
            defer {
                counter += 1
                metrics.pollTickCounter.increment(by: 1)
            }

            var tickLogger = logger
            tickLogger[metadataKey: "\(providerName).poll.tick.number"] = .stringConvertible(counter)
            tickLogger.debug("Poll tick starting")
            defer {
                tickLogger.debug("Poll tick stopping")
            }

            do {
                try await reloadIfNeeded(logger: tickLogger)
            } catch {
                tickLogger.debug(
                    "Poll tick failed, will retry on next tick",
                    metadata: [
                        "error": "\(error)"
                    ]
                )
                metrics.pollTickErrorCounter.increment(by: 1)
            }
        }
    }
}

// MARK: - ConfigProvider-like implementation

extension ReloadingFileProviderCore: ConfigProvider {

    internal func value(forKey key: AbsoluteConfigKey, type: ConfigType) throws -> LookupResult {
        try storage.withLock { storage in
            try storage.snapshot.value(forKey: key, type: type)
        }
    }

    internal func fetchValue(forKey key: AbsoluteConfigKey, type: ConfigType) async throws -> LookupResult {
        try await reloadIfNeeded(logger: logger)
        return try value(forKey: key, type: type)
    }

    internal func watchValue<Return>(
        forKey key: AbsoluteConfigKey,
        type: ConfigType,
        updatesHandler: (ConfigUpdatesAsyncSequence<Result<LookupResult, any Error>, Never>) async throws -> Return
    ) async throws -> Return {
        let (stream, continuation) = AsyncStream<Result<LookupResult, any Error>>
            .makeStream(bufferingPolicy: .bufferingNewest(1))
        let id = UUID()

        // Add watcher and get initial value
        let initialValue: Result<LookupResult, any Error> = storage.withLock { storage in
            storage.valueWatchers[key, default: [:]][id] = continuation
            metrics.watcherCount.record(storage.totalWatcherCount)
            return .init {
                try storage.snapshot.value(forKey: key, type: type)
            }
        }
        defer {
            storage.withLock { storage in
                storage.valueWatchers[key, default: [:]][id] = nil
                metrics.watcherCount.record(storage.totalWatcherCount)
            }
        }

        // Send initial value
        continuation.yield(initialValue)
        return try await updatesHandler(.init(stream))
    }

    internal func snapshot() -> any ConfigSnapshotProtocol {
        storage.withLock { $0.snapshot }
    }

    internal func watchSnapshot<Return>(
        updatesHandler: (ConfigUpdatesAsyncSequence<any ConfigSnapshotProtocol, Never>) async throws -> Return
    ) async throws -> Return {
        let (stream, continuation) = AsyncStream<SnapshotType>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let id = UUID()

        // Add watcher and get initial snapshot
        let initialSnapshot = storage.withLock { storage in
            storage.snapshotWatchers[id] = continuation
            metrics.watcherCount.record(storage.totalWatcherCount)
            return storage.snapshot
        }
        defer {
            // Clean up watcher
            storage.withLock { storage in
                storage.snapshotWatchers[id] = nil
                metrics.watcherCount.record(storage.totalWatcherCount)
            }
        }

        // Send initial snapshot
        continuation.yield(initialSnapshot)
        return try await updatesHandler(.init(stream.map { $0 }))
    }
}

#endif
