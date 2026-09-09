//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftConfiguration open source project
//
// Copyright (c) 2026 Apple Inc. and the SwiftConfiguration project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftConfiguration project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

#if Reloading && (os(macOS) || os(Linux))

import Testing
@testable import Configuration
import ConfigurationTestingInternal
import Foundation
import Logging
import Metrics
import ServiceLifecycle
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

struct ReloadingFileProviderSignalTests {
    @available(Configuration 1.0, *)
    @Test func sighupReloadsRunningProviders() async {
        // Run in a child process so the signal handlers don't outlive the test.
        await #expect(processExitsWith: .success) {
            // Make sure a stuck child fails instead of blocking the test run.
            signal(SIGALRM, SIG_DFL)
            alarm(15)
            defer { alarm(0) }

            try await withTestFileSystem { fileSystem, filePath, timestamp in
                // The poll interval is long enough that only SIGHUP can trigger a check.
                let logs = [CollectingLogHandler(), CollectingLogHandler()]
                var providers: [ReloadingFileProvider<TestSnapshot>] = []
                for log in logs {
                    providers.append(
                        try await ReloadingFileProvider<TestSnapshot>(
                            parsingOptions: .default,
                            filePath: filePath,
                            allowMissing: false,
                            pollInterval: .seconds(3_600),
                            fileSystem: fileSystem,
                            logger: Logger(label: "test", factory: { _ in log }),
                            metrics: NOOPMetricsHandler.instance
                        )
                    )
                }
                let first = providers[0]
                let second = providers[1]
                let serviceGroup = ServiceGroup(services: [second], logger: .noop)
                let firstTask = Task { try await first.run() }
                let secondTask = Task { try await serviceGroup.run() }
                defer {
                    firstTask.cancel()
                    secondTask.cancel()
                }

                // Both providers pick up the change on SIGHUP.
                for log in logs {
                    try await waitForReloadLog("Listening for SIGHUP", in: log)
                }
                fileSystem.update(
                    filePath: filePath,
                    timestamp: timestamp.addingTimeInterval(1),
                    contents: .file(contents: "key1=updated")
                )
                try #require(kill(getpid(), SIGHUP) == 0)  // ignore-unacceptable-language
                for (provider, log) in zip(providers, logs) {
                    try await waitForReloadLog("Reload check stopping", in: log)
                    let value = try provider.value(forKey: ["key1"], type: .string)
                    #expect(try value.value?.content.asString == "updated")
                    #expect(!log.currentEntries.contains { $0.metadata["\(provider.providerName).trigger"] == "poll" })
                }

                // A stopped provider ignores the signal, a running one doesn't.
                firstTask.cancel()
                try await firstTask.value
                fileSystem.update(
                    filePath: filePath,
                    timestamp: timestamp.addingTimeInterval(2),
                    contents: .file(contents: "key1=updatedAgain")
                )
                try #require(kill(getpid(), SIGHUP) == 0)  // ignore-unacceptable-language
                try await waitForReloadLog("Reload check stopping", count: 2, in: logs[1])
                let stoppedValue = try first.value(forKey: ["key1"], type: .string)
                let runningValue = try second.value(forKey: ["key1"], type: .string)
                #expect(try stoppedValue.value?.content.asString == "updated")
                #expect(try runningValue.value?.content.asString == "updatedAgain")

                await serviceGroup.triggerGracefulShutdown()
                try await secondTask.value
                #expect(logs[1].currentEntries.contains { $0.message == "File monitoring stopping" })
            }
        }
    }

    @available(Configuration 1.0, *)
    @Test func pollingContinuesAroundSighup() async {
        await #expect(processExitsWith: .success) {
            signal(SIGALRM, SIG_DFL)
            alarm(15)
            defer { alarm(0) }

            try await withTestFileSystem { fileSystem, filePath, _ in
                let logs = CollectingLogHandler()
                let provider = try await ReloadingFileProvider<TestSnapshot>(
                    parsingOptions: .default,
                    filePath: filePath,
                    allowMissing: false,
                    pollInterval: .milliseconds(20),
                    fileSystem: fileSystem,
                    logger: Logger(label: "test", factory: { _ in logs }),
                    metrics: NOOPMetricsHandler.instance
                )
                let task = Task { try await provider.run() }
                defer { task.cancel() }
                let trigger = "\(provider.providerName).trigger"

                // The first check is a poll, and by then the signal listener is installed.
                try await waitForReloadLog("Reload check stopping", metadata: [trigger: "poll"], in: logs)
                #expect(!logs.currentEntries.contains { $0.metadata[trigger] == "sighup" })

                // SIGHUP gets its own check, and polling carries on afterwards.
                try #require(kill(getpid(), SIGHUP) == 0)  // ignore-unacceptable-language
                try await waitForReloadLog("Reload check stopping", metadata: [trigger: "sighup"], in: logs)
                let polls = logs.currentEntries
                    .filter {
                        $0.message == "Reload check stopping" && $0.metadata[trigger] == "poll"
                    }
                    .count
                try await waitForReloadLog(
                    "Reload check stopping",
                    count: polls + 1,
                    metadata: [trigger: "poll"],
                    in: logs
                )

                task.cancel()
                try await task.value
            }
        }
    }
}

#endif
