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
        // Signals and their handlers stay inside the child process.
        await #expect(processExitsWith: .success) {
            signal(SIGALRM, SIG_DFL)
            alarm(15)
            defer { alarm(0) }

            try await withTestFileSystem { fileSystem, filePath, timestamp in
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
                    try await waitForReloadLog("SIGHUP check stopping", in: log)
                    let value = try provider.value(forKey: ["key1"], type: .string)
                    #expect(try value.value?.content.asString == "updated")
                    #expect(!log.currentEntries.contains { $0.message == "Poll tick starting" })
                }

                firstTask.cancel()
                do {
                    try await firstTask.value
                } catch is CancellationError {}

                fileSystem.update(
                    filePath: filePath,
                    timestamp: timestamp.addingTimeInterval(2),
                    contents: .file(contents: "key1=updatedAgain")
                )
                try #require(kill(getpid(), SIGHUP) == 0)  // ignore-unacceptable-language
                try await waitForReloadLog("SIGHUP check stopping", count: 2, in: logs[1])
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
}

#endif
