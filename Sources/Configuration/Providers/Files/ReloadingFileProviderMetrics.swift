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
import Metrics

/// Metrics for reloading file providers.
///
/// This type provides standardized metrics for file-based providers that support hot reloading.
internal struct ReloadingFileProviderMetrics {

    /// Counter for poll tick operations.
    ///
    /// This counter increments each time the provider checks the file's timestamp
    /// during its polling cycle, regardless of whether a reload was needed.
    let pollTickCounter: Counter

    /// Counter for poll tick errors.
    ///
    /// This counter increments when timestamp checking fails due to file system
    /// errors, permission issues, or other problems during polling.
    let pollTickErrorCounter: Counter

    /// Counter for successful reload operations.
    ///
    /// This counter increments each time the provider successfully reloads and
    /// parses the configuration file after detecting changes.
    let reloadCounter: Counter

    /// Counter for reload operation errors.
    ///
    /// This counter increments when file reloading fails due to parsing errors,
    /// file system issues, or other problems during the reload process.
    let reloadErrorCounter: Counter

    /// Gauge for current file size in bytes.
    ///
    /// This gauge tracks the size of the configuration file and is updated
    /// after each successful reload operation.
    let fileSize: Gauge

    /// Gauge for active watcher count.
    ///
    /// This gauge tracks the total number of active value and snapshot watchers
    /// currently registered with the provider.
    let watcherCount: Gauge

    /// Creates metrics for a reloading file provider.
    ///
    /// The metrics are created with standardized labels that include the provider
    /// name to distinguish between different provider types (JSON, YAML, and so on.)
    ///
    /// - Parameters:
    ///   - factory: The metrics factory to use for creating metric instances.
    ///   - providerName: The name of the provider. For example: "ReloadingFileProvider".
    init(factory: any MetricsFactory, providerName: String) {
        let prefix = providerName.lowercased()
        self.pollTickCounter = Counter(label: "\(prefix)_poll_ticks_total", factory: factory)
        self.pollTickErrorCounter = Counter(label: "\(prefix)_poll_errors_total", factory: factory)
        self.reloadCounter = Counter(label: "\(prefix)_reloads_total", factory: factory)
        self.reloadErrorCounter = Counter(label: "\(prefix)_reload_errors_total", factory: factory)
        self.fileSize = Gauge(label: "\(prefix)_file_size_bytes", factory: factory)
        self.watcherCount = Gauge(label: "\(prefix)_watchers_active", factory: factory)
    }
}

#endif
