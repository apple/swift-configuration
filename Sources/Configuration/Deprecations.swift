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

#if JSONSupport
/// A provider of configuration in JSON files.
@available(Configuration 1.0, *)
@available(*, deprecated, message: "Renamed to FileProvider<JSONSnapshot>")
public typealias JSONProvider = FileProvider<JSONSnapshot>
#endif

#if YAMLSupport
/// A provider of configuration in YAML files.
@available(Configuration 1.0, *)
@available(*, deprecated, message: "Renamed to FileProvider<YAMLSnapshot>")
public typealias YAMLProvider = FileProvider<YAMLSnapshot>
#endif

#if ReloadingSupport

#if JSONSupport
/// A reloading provider of configuration in JSON files.
@available(Configuration 1.0, *)
@available(*, deprecated, message: "Renamed to ReloadingFileProvider<JSONSnapshot>")
public typealias ReloadingJSONProvider = ReloadingFileProvider<JSONSnapshot>
#endif

#if YAMLSupport
/// A reloading provider of configuration in JSON files.
@available(Configuration 1.0, *)
@available(*, deprecated, message: "Renamed to ReloadingFileProvider<YAMLSnapshot>")
public typealias ReloadingYAMLProvider = ReloadingFileProvider<YAMLSnapshot>
#endif

#endif

/// An immutable snapshot of a configuration provider's state.
@available(Configuration 1.0, *)
@available(*, deprecated, renamed: "ConfigSnapshot")
public typealias ConfigSnapshotProtocol = ConfigSnapshot

@available(Configuration 1.0, *)
extension ConfigReader {
    /// Provides a snapshot of the current configuration state and passes it to the provided closure.
    ///
    /// This method creates a snapshot of the current configuration state and passes it to the
    /// provided closure. The snapshot reader provides read-only access to the configuration's state
    /// at the time the method was called.
    ///
    /// ```swift
    /// let result = config.withSnapshot { snapshot in
    ///     // Use snapshot to read config values
    ///     let cert = snapshot.string(forKey: "cert")
    ///     let privateKey = snapshot.string(forKey: "privateKey")
    ///     // Ensures that both values are coming from the same underlying snapshot and that a provider
    ///     // didn't change its internal state between the two `string(...)` calls.
    ///     return MyCert(cert: cert, privateKey: privateKey)
    /// }
    /// ```
    ///
    /// - Parameter body: A closure that takes a `ConfigSnapshotReader` and returns a value.
    /// - Returns: The value returned by the closure.
    /// - Throws: Rethrows any errors thrown by the provided closure.
    @available(*, deprecated, message: "Renamed to snapshot().")
    public func withSnapshot<Failure: Error, Return: ~Copyable>(
        _ body: (ConfigSnapshotReader) throws(Failure) -> Return
    ) throws(Failure) -> Return {
        let multiSnapshot = provider.snapshot()
        let snapshotReader = ConfigSnapshotReader(
            keyPrefix: keyPrefix,
            storage: .init(
                snapshot: multiSnapshot,
                accessReporter: accessReporter
            )
        )
        return try body(snapshotReader)
    }
}
