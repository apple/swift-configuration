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
public import FoundationEssentials
#else
public import Foundation
#endif
public import SystemPackage
import Synchronization

/// An access reporter that writes configuration access events to a file.
///
/// This reporter provides persistent logging of configuration access patterns by
/// writing structured event summaries to a file. Each access generates a single-line
/// entry with timestamp, key, value, and provider information, making it easy to
/// analyze configuration usage patterns and debug issues in production.
///
/// ## Usage
///
/// Create a file access logger and pass it to your configuration reader:
///
/// ```swift
/// let logger = try FileAccessLogger(filePath: "/tmp/config-access.log")
/// let config = ConfigReader(
///     provider: EnvironmentVariablesProvider(),
///     accessReporter: logger
/// )
/// ```
///
/// ## Environment variable activation
///
/// The file access logger can be automatically enabled for the entire process
/// using the `CONFIG_ACCESS_LOG_FILE` environment variable:
///
/// ```bash
/// CONFIG_ACCESS_LOG_FILE=/tmp/access.log ./my-app
/// ```
///
/// This allows operators to enable configuration access logging without
/// recompiling the application, making it useful for debugging production issues.
///
/// ## Log format
///
/// Each access event generates a single-line entry with the format:
/// ```
/// ✅ database.host -> "localhost" - provided by EnvironmentVariablesProvider / Get String from main.swift:42 at 2024-01-15T10:30:45.123Z
/// ```
///
/// The log entries include:
/// - Status emoji (✅ success, 🟡 default/nil, ❌ error)
/// - Configuration key that was accessed
/// - Resolved value (redacted for secrets)
/// - Provider that supplied the value or error information
/// - Access metadata (operation type, value type, source location, timestamp)
@available(Configuration 1.0, *)
public final class FileAccessLogger: Sendable {

    /// The file descriptor used for writing access events to the log file.
    private let fileDescriptor: Mutex<FileDescriptor>

    /// The date format style used for rendering timestamps in log entries.
    private let formatStyle: Date.ISO8601FormatStyle

    /// Creates a new file access logger that writes to the specified file path.
    ///
    /// The file and any necessary parent directories will be created if they don't exist.
    /// If the file already exists, new entries will be appended to it.
    ///
    /// ```swift
    /// // Log to a specific file
    /// let logger = try FileAccessLogger(filePath: "/var/log/config-access.log")
    ///
    /// // Log with custom timezone
    /// let logger = try FileAccessLogger(
    ///     filePath: "/tmp/access.log",
    ///     timeZone: TimeZone(identifier: "UTC")!
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - filePath: The file path where access events will be written.
    ///   - timeZone: The time zone for timestamp formatting. Defaults to the current system timezone.
    /// - Throws: An error if the file cannot be created or opened for writing.
    public convenience init(filePath: FilePath, timeZone: TimeZone = .current) throws {

        // Create parent directories if they don't exist
        let parentPath = filePath.removingLastComponent()
        if !parentPath.isEmpty {
            try FileManager.default.createDirectory(
                atPath: parentPath.string,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }

        // Create the file if it doesn't exist, then open it for writing
        let fileDescriptor = try FileDescriptor.open(
            filePath,
            .writeOnly,
            options: [.create, .append],
            permissions: [.ownerReadWrite, .groupRead, .otherRead]
        )

        try self.init(fileDescriptor: fileDescriptor, timeZone: timeZone)
    }

    /// Creates a new file access logger using an existing file descriptor.
    ///
    /// This initializer is primarily used internally and for testing purposes.
    /// It writes a header to the file indicating the process ID that is generating events.
    ///
    /// - Parameters:
    ///   - fileDescriptor: A file descriptor positioned for writing access events. ``FileAccessLogger`` closes it on deinit.
    ///   - timeZone: The time zone for timestamp formatting in log entries.
    /// - Throws: An error if the header cannot be written to the file.
    internal init(fileDescriptor: FileDescriptor, timeZone: TimeZone) throws {
        let pid = ProcessInfo.processInfo.processIdentifier
        let headerString = "---\nEmitting config events from process \(pid)\n---\n"
        let fd: FileDescriptor
        do {
            try fileDescriptor.writeAll(headerString.utf8)
            fd = fileDescriptor
        } catch {
            try fileDescriptor.close()
            throw error
        }
        self.fileDescriptor = .init(fd)
        var formatStyle = Date.ISO8601FormatStyle.iso8601
            .year().month().day().timeZone(separator: .omitted)
            .time(includingFractionalSeconds: true).timeSeparator(.colon)
        formatStyle.timeZone = timeZone
        self.formatStyle = formatStyle
    }

    deinit {
        self.fileDescriptor.withLock { fileDescriptor in
            _ = try? fileDescriptor.close()
        }
    }

    /// The locked storage for the singleton instance managed by the `detectedFromEnvironment()` method.
    private static let shared: Result<FileAccessLogger?, any Error> = {
        Result {
            let newInstance: FileAccessLogger?
            if let filePathString = ProcessInfo.processInfo.environment["CONFIG_ACCESS_LOG_FILE"] {
                newInstance = try FileAccessLogger(filePath: FilePath(filePathString))
            } else {
                newInstance = nil
            }
            return newInstance
        }
    }()

    /// Returns a shared file access logger instance controlled by environment variables.
    ///
    /// This method checks the `CONFIG_ACCESS_LOG_FILE` environment variable and creates
    /// a shared logger instance if the variable is set. The instance is cached and
    /// reused for subsequent calls.
    ///
    /// - Returns: A file access logger if the environment variable is set, nil otherwise.
    /// - Throws: An error if the environment variable is set but the logger cannot be created.
    internal static func detectedFromEnvironment() throws -> FileAccessLogger? {
        try shared.get()
    }
}

@available(Configuration 1.0, *)
extension FileAccessLogger: AccessReporter {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public func report(_ event: AccessEvent) {
        fileDescriptor.withLock { fileDescriptor in
            do {
                let eventData = renderedEvent(event)
                try fileDescriptor.writeAll(eventData)
            } catch {
                printToStderr("Failed to write to access log file: \(error)")
            }
        }
    }
}

@available(Configuration 1.0, *)
extension FileAccessLogger {
    /// Renders a string summary for the event.
    /// - Parameter event: The event to render.
    /// - Returns: A data representation of the rendered string.
    private func renderedEvent(_ event: AccessEvent) -> String.UTF8View {
        (event.renderedSummary(dateFormatStyle: formatStyle) + "\n").utf8
    }
}

@available(Configuration 1.0, *)
extension AccessEvent {
    /// Returns a human-readable single line string summarizing the access event.
    /// - Parameter dateFormatStyle: The format style used for rendering dates.
    /// - Returns: The rendered string.
    fileprivate func renderedSummary(dateFormatStyle: Date.ISO8601FormatStyle) -> String {
        // Compute which provider actually supplied the final value, might be nil.
        let resolvedProvider = providerResults.first(where: { providerResult in
            switch providerResult.result {
            case .success(let value) where value.value != nil:
                return true
            default:
                return false
            }
        })

        // ✅ foo.bar -> "value" - provided by EnvironmentVariablesProvider
        // 🟡 foo.baz -> "defaultValue" - returned the default
        // 🟡 foo.baz -> nil - no default provided
        // ❌ foo.ban -> "defaultValue" / nil - EnvironmentVariablesProvider threw an error: ...

        let emoji: String
        let valueString: String
        let statusString: String
        switch result {
        case .success(let maybeValue):
            if let maybeValue {
                valueString = maybeValue.isSecret ? "<REDACTED>" : maybeValue.content.renderedDescription
            } else {
                valueString = "<nil>"
            }

            if let resolvedProvider {
                if let conversionError {
                    statusString =
                        "provided by \(resolvedProvider.providerName) but failed to convert: \(conversionError)"
                    emoji = "🟡"
                } else {
                    statusString = "provided by \(resolvedProvider.providerName)"
                    emoji = "✅"
                }
            } else if maybeValue != nil {
                statusString = "all providers returned nil, got the default value"
                emoji = "🟡"
            } else {
                statusString = "all providers returned nil"
                emoji = "🟡"
            }
        case .failure(let error):
            valueString = "<error>"
            statusString = "threw an error: \(error)"
            emoji = "❌"
        }
        let metadataString =
            "\(metadata.accessKind.rawValue.capitalized) \(metadata.valueType) from \(metadata.sourceLocation) at \(metadata.accessTimestamp.formatted(dateFormatStyle))"
        return "\(emoji) \(metadata.key.description) -> \"\(valueString)\" - \(statusString) / \(metadataString)"
    }
}

@available(Configuration 1.0, *)
extension ConfigContent {
    /// Returns a string representation of the config value, formatting complex types appropriately.
    ///
    /// Assumes default encoding for bytes (base64) and arrays (comma-separated).
    fileprivate var renderedDescription: String {
        // TODO: Make this more correct by taking a bytesValueEncoder and arrayValueEncoder, rather than assuming the default.
        switch self {
        case .string(let string):
            return string
        case .int(let int):
            return "\(int)"
        case .double(let double):
            return "\(double)"
        case .bool(let bool):
            return "\(bool)"
        case .bytes(let bytes):
            return Data(bytes).base64EncodedString()
        case .stringArray(let array):
            return array.joined(separator: ",")
        case .intArray(let array):
            return array.map(\.description).joined(separator: ",")
        case .doubleArray(let array):
            return array.map(\.description).joined(separator: ",")
        case .boolArray(let array):
            return array.map(\.description).joined(separator: ",")
        case .byteChunkArray(let array):
            return array.map { Data($0).base64EncodedString() }.joined(separator: ",")
        }
    }
}
