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

public import SystemPackage
public import ServiceLifecycle
public import Logging
public import Metrics
import AsyncAlgorithms
import Synchronization

/// A configuration provider that reads configuration from a file on disk with automatic reloading capability.
///
/// `ReloadingFileProvider` is a generic file-based configuration provider that monitors
/// a configuration file for changes and automatically reloads the data when
/// the file is modified. This provider works with different file formats by using
/// different snapshot types that conform to ``FileConfigSnapshotProtocol``.
///
/// ## Usage
///
/// Create a reloading provider by specifying the snapshot type and file path:
///
/// ```swift
/// // Using with a JSON snapshot and a custom poll interval
/// let jsonProvider = try await ReloadingFileProvider<JSONSnapshot>(
///     filePath: "/etc/config.json",
///     pollInterval: .seconds(30)
/// )
///
/// // Using with a YAML snapshot
/// let yamlProvider = try await ReloadingFileProvider<YAMLSnapshot>(
///     filePath: "/etc/config.yaml"
/// )
/// ```
///
/// ## Service integration
///
/// This provider implements the `Service` protocol and must be run within a `ServiceGroup`
/// to enable automatic reloading:
///
/// ```swift
/// let provider = try await ReloadingFileProvider<JSONSnapshot>(filePath: "/etc/config.json")
/// let serviceGroup = ServiceGroup(services: [provider], logger: logger)
/// try await serviceGroup.run()
/// ```
///
/// The provider monitors the file by polling at the specified interval (default: 15 seconds)
/// and notifies any active watchers when changes are detected.
///
/// ## Configuration from a reader
///
/// You can also initialize the provider using a configuration reader:
///
/// ```swift
/// let envConfig = ConfigReader(provider: EnvironmentVariablesProvider())
/// let provider = try await ReloadingFileProvider<JSONSnapshot>(config: envConfig)
/// ```
///
/// This expects a `filePath` key in the configuration that specifies the path to the file.
/// For a full list of read configuration keys, check out ``FileProvider/init(snapshotType:parsingOptions:config:)``.
///
/// ## File monitoring
///
/// The provider detects changes by monitoring both file timestamps and symlink target changes.
/// When a change is detected, it reloads the file and notifies all active watchers of the
/// updated configuration values.
@available(Configuration 1.0, *)
public final class ReloadingFileProvider<SnapshotType: FileConfigSnapshotProtocol>: Sendable {

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

    /// The options used for parsing the data.
    private let parsingOptions: SnapshotType.ParsingOptions

    /// The file system interface for reading files and timestamps.
    private let fileSystem: any CommonProviderFileSystem

    /// The original unresolved file path provided by the user, may contain symlinks.
    private let filePath: FilePath

    /// The interval between polling checks.
    private let pollInterval: Duration

    /// The human-readable name of the provider.
    public let providerName: String

    /// The logger for this provider instance.
    private let logger: Logger

    /// The metrics collector for this provider instance.
    private let metrics: ReloadingFileProviderMetrics

    internal init(
        snapshotType: SnapshotType.Type = SnapshotType.self,
        parsingOptions: SnapshotType.ParsingOptions,
        filePath: FilePath,
        pollInterval: Duration,
        fileSystem: any CommonProviderFileSystem,
        logger: Logger,
        metrics: any MetricsFactory
    ) async throws {
        self.parsingOptions = parsingOptions
        self.filePath = filePath
        self.pollInterval = pollInterval
        self.providerName = "ReloadingFileProvider<\(SnapshotType.self)>"
        self.fileSystem = fileSystem

        // Set up the logger with metadata
        var logger = logger
        logger[metadataKey: "\(providerName).filePath"] = .string(filePath.lastComponent?.string ?? "<nil>")
        logger[metadataKey: "\(providerName).pollInterval.seconds"] = .string(
            pollInterval.components.seconds.description
        )
        self.logger = logger

        // Set up metrics
        self.metrics = ReloadingFileProviderMetrics(
            factory: metrics,
            providerName: providerName
        )

        // Perform initial load
        logger.debug("Performing initial file load")
        let realPath = try await fileSystem.resolveSymlinks(atPath: filePath)
        let timestamp = try await fileSystem.lastModifiedTimestamp(atPath: realPath)
        let data = try await fileSystem.fileContents(atPath: realPath)
        let initialSnapshot = try snapshotType.init(
            data: data,
            providerName: providerName,
            parsingOptions: parsingOptions
        )

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
            "Successfully initialized reloading file provider",
            metadata: [
                "\(providerName).realFilePath": .string(realPath.string),
                "\(providerName).initialTimestamp": .stringConvertible(timestamp.formatted(.iso8601)),
                "\(providerName).fileSize": .stringConvertible(data.count),
            ]
        )
    }

    /// Creates a reloading file provider that monitors the specified file path.
    ///
    /// - Parameters:
    ///   - snapshotType: The type of snapshot to create from the file contents.
    ///   - parsingOptions: Options used by the snapshot to parse the file data.
    ///   - filePath: The path to the configuration file to monitor.
    ///   - pollInterval: How often to check for file changes.
    ///   - logger: The logger instance to use for this provider.
    ///   - metrics: The metrics factory to use for monitoring provider performance.
    /// - Throws: If the file cannot be read or if snapshot creation fails.
    public convenience init(
        snapshotType: SnapshotType.Type = SnapshotType.self,
        parsingOptions: SnapshotType.ParsingOptions = .default,
        filePath: FilePath,
        pollInterval: Duration = .seconds(15),
        logger: Logger = Logger(label: "ReloadingFileProvider"),
        metrics: any MetricsFactory = MetricsSystem.factory
    ) async throws {
        try await self.init(
            snapshotType: snapshotType,
            parsingOptions: parsingOptions,
            filePath: filePath,
            pollInterval: pollInterval,
            fileSystem: LocalCommonProviderFileSystem(),
            logger: logger,
            metrics: metrics
        )
    }

    /// Creates a reloading file provider using configuration from a reader.
    ///
    /// ## Configuration keys
    /// - `filePath` (string, required): The path to the configuration file to monitor.
    /// - `pollIntervalSeconds` (int, optional, default: 15): How often to check for file changes in seconds.
    ///
    /// - Parameters:
    ///   - snapshotType: The type of snapshot to create from the file contents.
    ///   - parsingOptions: Options used by the snapshot to parse the file data.
    ///   - config: A configuration reader that contains the required configuration keys.
    ///   - logger: The logger instance to use for this provider.
    ///   - metrics: The metrics factory to use for monitoring provider performance.
    /// - Throws: If required configuration keys are missing, if the file cannot be read, or if snapshot creation fails.
    public convenience init(
        snapshotType: SnapshotType.Type = SnapshotType.self,
        parsingOptions: SnapshotType.ParsingOptions = .default,
        config: ConfigReader,
        logger: Logger = Logger(label: "ReloadingFileProvider"),
        metrics: any MetricsFactory = MetricsSystem.factory
    ) async throws {
        try await self.init(
            snapshotType: snapshotType,
            parsingOptions: parsingOptions,
            filePath: config.requiredString(forKey: "filePath", as: FilePath.self),
            pollInterval: .seconds(config.int(forKey: "pollIntervalSeconds", default: 15)),
            fileSystem: LocalCommonProviderFileSystem(),
            logger: logger,
            metrics: metrics
        )
    }

    /// Checks if the file has changed and reloads it if necessary.
    ///
    /// This method performs the core file monitoring logic by checking both the file's
    /// last modified timestamp and its resolved path (in case of symlinks). If changes
    /// are detected, it reloads the file contents, creates a new snapshot, and notifies
    /// any active watchers of the changes.
    ///
    /// - Parameter logger: The logger to use during the reload operation.
    /// - Throws: File system errors or snapshot creation errors.
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
        let newSnapshot = try SnapshotType.init(
            data: data,
            providerName: providerName,
            parsingOptions: parsingOptions
        )

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

@available(Configuration 1.0, *)
extension ReloadingFileProvider: CustomStringConvertible {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public var description: String {
        storage.withLock { $0.snapshot.description }
    }
}

@available(Configuration 1.0, *)
extension ReloadingFileProvider: CustomDebugStringConvertible {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public var debugDescription: String {
        storage.withLock { $0.snapshot.debugDescription }
    }
}

@available(Configuration 1.0, *)
extension ReloadingFileProvider: ConfigProvider {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public func value(forKey key: AbsoluteConfigKey, type: ConfigType) throws -> LookupResult {
        try storage.withLock { storage in
            try storage.snapshot.value(forKey: key, type: type)
        }
    }

    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public func fetchValue(
        forKey key: AbsoluteConfigKey,
        type: ConfigType
    ) async throws -> LookupResult {
        try await reloadIfNeeded(logger: logger)
        return try value(forKey: key, type: type)
    }

    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public func watchValue<Return>(
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

    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public func snapshot() -> any ConfigSnapshotProtocol {
        storage.withLock { $0.snapshot }
    }

    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public func watchSnapshot<Return>(
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

@available(Configuration 1.0, *)
extension ReloadingFileProvider: Service {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public func run() async throws {
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

#endif
