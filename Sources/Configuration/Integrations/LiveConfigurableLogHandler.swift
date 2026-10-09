#if LoggingSupport && ReloadingSupport

public import Logging
public import ServiceLifecycle
import Synchronization

/// A log handler whose log level can be controlled the hot-reloaded configuration value `logLevel`.
///
/// ## Usage
///
/// ```swift
/// // An existing log handler, for example `StreamLogHandler.standardError(...)`.
/// let logHandler = ...
/// // A config reader with at least one reloading provider, containing a value for key `logLevel`.
/// let configReader = ...
/// let configurableLogHandler = LiveConfigurableLogHandler(
///     upstream: logHandler,
///     config: configReader,
///     diagnosticLogger: Logger(label: "LiveConfigurableLogHandler", factory: { _ in logHandler })
/// )
///
/// // 1. Add `configurableLogHandler` to a ServiceGroup.
/// // 2. Bootstrap `configurableLogHandler` as the Swift Log backend.
/// ```
public struct LiveConfigurableLogHandler<Upstream: LogHandler> {
    var upstream: Upstream
    var service: LiveConfigurableLogHandlerService

    init(
        upstream: Upstream,
        service: LiveConfigurableLogHandlerService
    ) {
        self.upstream = upstream
        self.service = service
    }

    public init(upstream: Upstream, config: ConfigReader, diagnosticLogger: Logger) {
        self.init(
            upstream: upstream,
            service: .init(
                config: config,
                diagnosticLogger: diagnosticLogger
            )
        )
    }
}

extension LiveConfigurableLogHandler: Service {
    public func run() async throws {
        try await service.run()
    }
}

extension LiveConfigurableLogHandler: LogHandler {
    public var logLevel: Logger.Level {
        get {
            service.currentLogLevel ?? upstream.logLevel
        }
        set {
            upstream.logLevel = newValue
        }
    }

    public var metadata: Logger.Metadata {
        get { upstream.metadata }
        set { upstream.metadata = newValue }
    }

    public subscript(metadataKey key: String) -> Logging.Logger.Metadata.Value? {
        get {
            upstream[metadataKey: key]
        }
        set(newValue) {
            upstream[metadataKey: key] = newValue
        }
    }

    public func log(
        level: Logger.Level,
        message: Logger.Message,
        metadata: Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        guard level >= logLevel else {
            return
        }
        upstream.log(
            level: level,
            message: message,
            metadata: metadata,
            source: source,
            file: file,
            function: function,
            line: line
        )
    }
}

extension ConfigKey {
    fileprivate static let logLevel: Self = ["logLevel"]
}

final class LiveConfigurableLogHandlerService: Sendable {

    private let config: ConfigReader
    private let diagnosticLogger: Logger

    private struct Storage {
        var logLevel: Logger.Level?
    }
    private let storage: Mutex<Storage>

    var currentLogLevel: Logger.Level? {
        storage.withLock { $0.logLevel }
    }

    init(
        config: ConfigReader,
        diagnosticLogger: Logger
    ) {
        self.config = config
        self.diagnosticLogger = diagnosticLogger
        self.storage = .init(.init(logLevel: config.string(forKey: .logLevel)))
    }
}

extension LiveConfigurableLogHandlerService {
    func run() async throws {
        diagnosticLogger.debug("Starting")
        defer {
            diagnosticLogger.debug("Stopping")
        }
        try await config.watchString(forKey: .logLevel, as: Logger.Level.self) { updates in
            for await logLevel in updates {
                let oldLogLevel = storage.withLock { storage in
                    let oldLogLevel = storage.logLevel
                    storage.logLevel = logLevel
                    return oldLogLevel
                }
                diagnosticLogger.debug(
                    "Updated log level",
                    metadata: [
                        "newLogLevelOverride": "\(logLevel?.rawValue ?? "<nil>")",
                        "oldLogLevelOverride": "\(oldLogLevel?.rawValue ?? "<nil>")",
                    ]
                )
            }
        }
    }
}

#endif
