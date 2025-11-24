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
import FoundationEssentials
#else
import Foundation
#endif

@available(Configuration 1.0, *)
extension ConfigValue {
    /// Returns a copy of the config value marked as secret.
    ///
    /// - Returns: A copy of self with `isSecret` set to true.
    fileprivate func asSecret() -> Self {
        var copy = self
        copy.isSecret = true
        return copy
    }
}

@available(Configuration 1.0, *)
extension Result<ConfigValue?, any Error> {
    /// Returns a copy of the result with the value marked as secret.
    ///
    /// - Returns: A copy of self with the value's `isSecret` set to true.
    fileprivate func asSecret() -> Self {
        map { $0?.asSecret() }
    }
}

@available(Configuration 1.0, *)
extension LookupResult {
    /// Returns a copy of the config value marked as secret.
    ///
    /// - Returns: A copy of self with the value's `isSecret` set to true.
    fileprivate func asSecret() -> Self {
        var copy = self
        copy.value = copy.value?.asSecret()
        return copy
    }
}

@available(Configuration 1.0, *)
extension Result<LookupResult, any Error> {
    /// Returns a copy of the result with the value marked as secret.
    ///
    /// - Returns: A copy of self with the value's `isSecret` set to true.
    fileprivate func asSecret() -> Self {
        map { $0.asSecret() }
    }
}

@available(Configuration 1.0, *)
extension AccessEvent.ProviderResult {
    /// Returns a copy of the result marked as secret.
    ///
    /// - Returns: A copy of self with result's `isSecret` set to true.
    fileprivate func asSecret() -> Self {
        var copy = self
        copy.result = copy.result.asSecret()
        return copy
    }
}

/// Applies secret marking to provider results and configuration values.
///
/// This function conditionally marks provider results and configuration values as secret
/// based on the provided flag. When `isSecret` is true, the library marks all provider results
/// and the configuration value as secret for proper handling in access reporting
/// and logging systems.
///
/// - Parameters:
///   - isSecret: Whether to mark the values as secret.
///   - tuple: A tuple containing provider results and a configuration value result.
/// - Returns: The tuple with values marked as secret if the flag is true, otherwise unchanged.
@available(Configuration 1.0, *)
private func mergingIsSecret(
    _ isSecret: Bool,
    _ tuple: ([AccessEvent.ProviderResult], Result<ConfigValue?, any Error>)
) -> ([AccessEvent.ProviderResult], Result<ConfigValue?, any Error>) {
    guard isSecret else {
        // Skip if false.
        return tuple
    }
    return (
        tuple.0.map { $0.asSecret() },
        tuple.1.asSecret()
    )
}

/// Retrieves a configuration value from a provider with full access tracking.
///
/// This is the core implementation function that handles configuration value retrieval,
/// type conversion, secret handling, and access event reporting. It coordinates between
/// the configuration provider, type conversion system, and the access reporting infrastructure.
///
/// ## Process flow
///
/// 1. Construct the absolute configuration key from the prefix and relative key.
/// 2. Retrieve the value from the provider using the provided closure.
/// 3. Apply secret marking if requested.
/// 4. Attempt type conversion using the unwrap closure.
/// 5. Report the access event if an access reporter is configured.
/// 6. Return the converted value or nil if not found/conversion failed.
///
/// - Parameters:
///   - key: The relative configuration key to look up.
///   - type: The expected configuration value type for validation.
///   - isSecret: Whether to treat the value as secret regardless of provider marking.
///   - keyPrefix: Optional prefix to create the absolute key.
///   - valueClosure: Closure that retrieves the raw value from the provider.
///   - accessReporter: Optional reporter for tracking configuration access.
///   - unwrap: Closure to convert raw configuration content to the target type.
///   - wrap: Closure to convert the typed value back to configuration content.
///   - fileID: Source file identifier for access event metadata.
///   - line: Source line number for access event metadata.
/// - Returns: The converted configuration value, or `nil` if not found or conversion fails.
@available(Configuration 1.0, *)
internal func valueFromReader<Value>(
    forKey key: ConfigKey,
    type: ConfigType,
    isSecret: Bool,
    keyPrefix: AbsoluteConfigKey?,
    valueClosure: (AbsoluteConfigKey, ConfigType) -> ([AccessEvent.ProviderResult], Result<ConfigValue?, any Error>),
    accessReporter: (any AccessReporter)?,
    unwrap: (ConfigContent) throws -> Value,
    wrap: (Value) -> ConfigContent,
    fileID: String,
    line: UInt
) -> Value? {
    let absoluteKey = keyPrefix.appending(key)
    let (providerResults, value) = mergingIsSecret(
        isSecret,
        valueClosure(absoluteKey, type)
    )

    let finalValue: (Value, Bool)?
    let conversionError: (any Error)?

    let configValue: ConfigValue?
    do {
        configValue = try value.get()
    } catch {
        // the error is surfaced through the `providerResults`
        configValue = nil
    }

    do {
        finalValue = try configValue.map { (try unwrap($0.content), $0.isSecret) }
        conversionError = nil
    } catch {
        finalValue = nil
        conversionError = error
    }

    if let accessReporter {
        accessReporter.report(
            AccessEvent(
                metadata: .init(
                    accessKind: .get,
                    key: absoluteKey,
                    valueType: type,
                    sourceLocation: .init(fileID: fileID, line: line),
                    accessTimestamp: .now
                ),
                providerResults: providerResults,
                conversionError: conversionError,
                result: .success(finalValue.flatMap { ConfigValue(wrap($0.0), isSecret: $0.1) })
            )
        )
    }

    return finalValue?.0
}

/// Retrieves the configuration value from the underlying provider.
///
/// - Parameters:
///   - key: The config key to look up.
///   - type: The expected config value type.
///   - isSecret: Whether the value should be treated as secret.
///   - defaultValue: The default value, if the provider returns nil or the conversion fails.
///   - keyPrefix: Optional prefix to prepend to the key to form an absolute key.
///   - valueClosure: A closure that retrieves the value from the underlying provider.
///   - accessReporter: A reporter to track access events.
///   - unwrap: A closure to convert the raw configuration content to the requested type.
///   - wrap: A closure to convert the typed value back to configuration content.
///   - fileID: Source file identifier used for event reporting.
///   - line: Source line number used for event reporting.
/// - Returns: The configuration value converted to the requested type.
@available(Configuration 1.0, *)
internal func valueFromReader<Value>(
    forKey key: ConfigKey,
    type: ConfigType,
    isSecret: Bool,
    default defaultValue: Value,
    keyPrefix: AbsoluteConfigKey?,
    valueClosure: (AbsoluteConfigKey, ConfigType) -> ([AccessEvent.ProviderResult], Result<ConfigValue?, any Error>),
    accessReporter: (any AccessReporter)?,
    unwrap: (ConfigContent) throws -> Value,
    wrap: (Value) -> ConfigContent,
    fileID: String,
    line: UInt
) -> Value {
    let absoluteKey = keyPrefix.appending(key)
    let (providerResults, value) = mergingIsSecret(
        isSecret,
        valueClosure(absoluteKey, type)
    )

    let finalValue: (Value, Bool)
    let conversionError: (any Error)?

    let configValue: ConfigValue?
    do {
        configValue = try value.get()
    } catch {
        // the error is surfaced through the `providerResults`
        configValue = nil
    }

    do {
        finalValue =
            try configValue.map { (try unwrap($0.content), $0.isSecret) }
            ?? (defaultValue, isSecret)
        conversionError = nil
    } catch {
        finalValue = (defaultValue, isSecret)
        conversionError = error
    }

    if let accessReporter {
        accessReporter.report(
            AccessEvent(
                metadata: .init(
                    accessKind: .get,
                    key: absoluteKey,
                    valueType: type,
                    sourceLocation: .init(fileID: fileID, line: line),
                    accessTimestamp: .now
                ),
                providerResults: providerResults,
                conversionError: conversionError,
                result: .success(ConfigValue(wrap(finalValue.0), isSecret: finalValue.1))
            )
        )
    }

    return finalValue.0
}

/// Retrieves the required configuration value from the underlying provider.
///
/// - Parameters:
///   - key: The config key to look up.
///   - type: The expected config value type.
///   - isSecret: Whether the value should be treated as secret.
///   - keyPrefix: Optional prefix to prepend to the key to form an absolute key.
///   - valueClosure: A closure that retrieves the value from the underlying provider.
///   - accessReporter: A reporter to track access events.
///   - unwrap: A closure to convert the raw configuration content to the requested type.
///   - wrap: A closure to convert the typed value back to configuration content.
///   - fileID: Source file identifier used for event reporting.
///   - line: Source line number used for event reporting.
/// - Throws: `ConfigError.missingRequiredConfigValue` if the configuration value is not found, or any error thrown
///   by the `unwrap` closure if conversion fails.
/// - Returns: The configuration value converted to the requested type.
@available(Configuration 1.0, *)
internal func requiredValueFromReader<Value>(
    forKey key: ConfigKey,
    type: ConfigType,
    isSecret: Bool,
    keyPrefix: AbsoluteConfigKey?,
    valueClosure: (AbsoluteConfigKey, ConfigType) -> ([AccessEvent.ProviderResult], Result<ConfigValue?, any Error>),
    accessReporter: (any AccessReporter)?,
    unwrap: (ConfigContent) throws -> Value,
    wrap: (Value) -> ConfigContent,
    fileID: String,
    line: UInt
) throws -> Value {
    let absoluteKey = keyPrefix.appending(key)
    let (providerResults, value) = mergingIsSecret(
        isSecret,
        valueClosure(absoluteKey, type)
    )

    let configValue = value.flatMap { configValue in
        if let configValue {
            .success(configValue)
        } else {
            .failure(ConfigError.missingRequiredConfigValue(absoluteKey))
        }
    }

    var conversionError: (any Error)?
    let finalResult: Result<(Value, Bool), any Error> = configValue.flatMap { configValue in
        do {
            return .success((try unwrap(configValue.content), configValue.isSecret))
        } catch {
            conversionError = error
            return .failure(error)
        }
    }

    if let accessReporter {
        accessReporter.report(
            AccessEvent(
                metadata: .init(
                    accessKind: .get,
                    key: absoluteKey,
                    valueType: type,
                    sourceLocation: .init(fileID: fileID, line: line),
                    accessTimestamp: .now
                ),
                providerResults: providerResults,
                conversionError: conversionError,
                result: finalResult.map { ConfigValue(wrap($0.0), isSecret: $0.1) }
            )
        )
    }
    return try finalResult.get().0
}

@available(Configuration 1.0, *)
extension ConfigReader {

    /// Gets a config value synchronously.
    ///
    /// - Parameters:
    ///   - key: The config key.
    ///   - type: The expected type of the config value.
    ///   - isSecret: Whether the value should be treated as secret.
    ///   - unwrap: A closure to extract the typed value from the raw config content.
    ///   - wrap: A closure to wrap the typed value back into config content.
    ///   - fileID: The source file identifier (used for event metadata).
    ///   - line: The line number (used for event metadata).
    /// - Returns: The unwrapped typed value, or `nil`.
    internal func value<Value>(
        forKey key: ConfigKey,
        type: ConfigType,
        isSecret: Bool,
        unwrap: (ConfigContent) throws -> Value,
        wrap: (Value) -> ConfigContent,
        fileID: String,
        line: UInt
    ) -> Value? {
        valueFromReader(
            forKey: key,
            type: type,
            isSecret: isSecret,
            keyPrefix: keyPrefix,
            valueClosure: provider.value,
            accessReporter: accessReporter,
            unwrap: unwrap,
            wrap: wrap,
            fileID: fileID,
            line: line
        )
    }

    /// Gets a config value synchronously, returning a default if missing.
    ///
    /// - Parameters:
    ///   - key: The config key.
    ///   - type: The expected type of the config value.
    ///   - isSecret: Whether the value should be treated as secret.
    ///   - defaultValue: The value to return if no config value is found.
    ///   - unwrap: A closure to extract the typed value from the raw config content.
    ///   - wrap: A closure to wrap the typed value back into config content.
    ///   - fileID: The source file identifier (used for event metadata).
    ///   - line: The line number (used for event metadata).
    /// - Returns: The unwrapped typed value, or the default value.
    internal func value<Value>(
        forKey key: ConfigKey,
        type: ConfigType,
        isSecret: Bool,
        default defaultValue: Value,
        unwrap: (ConfigContent) throws -> Value,
        wrap: (Value) -> ConfigContent,
        fileID: String,
        line: UInt
    ) -> Value {
        valueFromReader(
            forKey: key,
            type: type,
            isSecret: isSecret,
            default: defaultValue,
            keyPrefix: keyPrefix,
            valueClosure: provider.value,
            accessReporter: accessReporter,
            unwrap: unwrap,
            wrap: wrap,
            fileID: fileID,
            line: line
        )
    }

    /// Gets a required config value synchronously.
    ///
    /// - Parameters:
    ///   - key: The config key.
    ///   - type: The expected type of the config value.
    ///   - isSecret: Whether the value should be treated as secret.
    ///   - unwrap: A closure to extract the typed value from the raw config content.
    ///   - wrap: A closure to wrap the typed value back into config content.
    ///   - fileID: The source file identifier (used for event metadata).
    ///   - line: The line number (used for event metadata).
    /// - Throws: A `ConfigError` if the value is missing or cannot be unwrapped.
    /// - Returns: The unwrapped typed value.
    internal func requiredValue<Value>(
        forKey key: ConfigKey,
        type: ConfigType,
        isSecret: Bool,
        unwrap: (ConfigContent) throws -> Value,
        wrap: (Value) -> ConfigContent,
        fileID: String,
        line: UInt
    ) throws -> Value {
        try requiredValueFromReader(
            forKey: key,
            type: type,
            isSecret: isSecret,
            keyPrefix: keyPrefix,
            valueClosure: provider.value,
            accessReporter: accessReporter,
            unwrap: unwrap,
            wrap: wrap,
            fileID: fileID,
            line: line
        )
    }

    /// Fetches a config value asynchronously.
    ///
    /// - Parameters:
    ///   - key: The config key.
    ///   - type: The expected type of the config value.
    ///   - isSecret: Whether the value should be treated as secret.
    ///   - unwrap: A closure to extract the typed value from the raw config content.
    ///   - wrap: A closure to wrap the typed value back into config content.
    ///   - fileID: The source file identifier (used for event metadata).
    ///   - line: The line number (used for event metadata).
    /// - Throws: An error if the fetch fails.
    /// - Returns: The unwrapped typed value, or `nil`.
    internal func fetchValue<Value>(
        forKey key: ConfigKey,
        type: ConfigType,
        isSecret: Bool,
        unwrap: (ConfigContent) throws -> Value,
        wrap: (Value) -> ConfigContent,
        fileID: String,
        line: UInt
    ) async throws -> Value? {
        let absoluteKey = keyPrefix.appending(key)
        let (providerResults, value) = mergingIsSecret(
            isSecret,
            await provider.fetchValue(forKey: absoluteKey, type: type)
        )

        var conversionError: (any Error)?
        let finalResult: Result<(Value, Bool)?, any Error> = value.flatMap { configValue in
            if let configValue {
                do {
                    return .success((try unwrap(configValue.content), configValue.isSecret))
                } catch {
                    conversionError = error
                    return .failure(error)
                }
            } else {
                return .success(nil)
            }
        }

        if let accessReporter {
            accessReporter.report(
                AccessEvent(
                    metadata: .init(
                        accessKind: .fetch,
                        key: absoluteKey,
                        valueType: type,
                        sourceLocation: .init(fileID: fileID, line: line),
                        accessTimestamp: .now
                    ),
                    providerResults: providerResults,
                    conversionError: conversionError,
                    result: finalResult.map { success in
                        success.flatMap {
                            ConfigValue(wrap($0.0), isSecret: $0.1)
                        }
                    }
                )
            )
        }
        return try finalResult.get()?.0
    }

    /// Fetches a config value asynchronously, returning a default if missing.
    ///
    /// - Parameters:
    ///   - key: The config key.
    ///   - type: The expected type of the config value.
    ///   - isSecret: Whether the value should be treated as secret.
    ///   - defaultValue: The value to return if no config value is found.
    ///   - unwrap: A closure to extract the typed value from the raw config content.
    ///   - wrap: A closure to wrap the typed value back into config content.
    ///   - fileID: The source file identifier (used for event metadata).
    ///   - line: The line number (used for event metadata).
    /// - Throws: An error if the fetch fails.
    /// - Returns: The unwrapped typed value, or the default value.
    internal func fetchValue<Value>(
        forKey key: ConfigKey,
        type: ConfigType,
        isSecret: Bool,
        default defaultValue: Value,
        unwrap: (ConfigContent) throws -> Value,
        wrap: (Value) -> ConfigContent,
        fileID: String,
        line: UInt
    ) async throws -> Value {
        let absoluteKey = keyPrefix.appending(key)
        let (providerResults, value) = mergingIsSecret(
            isSecret,
            await provider.fetchValue(forKey: absoluteKey, type: type)
        )
        var conversionError: (any Error)?
        let finalResult: Result<(Value, Bool), any Error> = value.flatMap { configValue in
            if let configValue {
                do {
                    return .success((try unwrap(configValue.content), configValue.isSecret))
                } catch {
                    conversionError = error
                    return .failure(error)
                }
            } else {
                return .success((defaultValue, isSecret))
            }
        }
        if let accessReporter {
            accessReporter.report(
                AccessEvent(
                    metadata: .init(
                        accessKind: .fetch,
                        key: absoluteKey,
                        valueType: type,
                        sourceLocation: .init(fileID: fileID, line: line),
                        accessTimestamp: .now
                    ),
                    providerResults: providerResults,
                    conversionError: conversionError,
                    result: finalResult.map { ConfigValue(wrap($0.0), isSecret: $0.1) }
                )
            )
        }
        return try finalResult.get().0
    }

    /// Fetches a required config value asynchronously.
    ///
    /// - Parameters:
    ///   - key: The config key.
    ///   - type: The expected type of the config value.
    ///   - isSecret: Whether the value should be treated as secret.
    ///   - unwrap: A closure to extract the typed value from the raw config content.
    ///   - wrap: A closure to wrap the typed value back into config content.
    ///   - fileID: The source file identifier (used for event metadata).
    ///   - line: The line number (used for event metadata).
    /// - Throws: A `ConfigError` if the value is missing or cannot be converted.
    /// - Returns: The unwrapped typed value.
    internal func fetchRequiredValue<Value>(
        forKey key: ConfigKey,
        type: ConfigType,
        isSecret: Bool,
        unwrap: (ConfigContent) throws -> Value,
        wrap: (Value) -> ConfigContent,
        fileID: String,
        line: UInt
    ) async throws -> Value {
        let absoluteKey = keyPrefix.appending(key)
        let (providerResults, value) = mergingIsSecret(
            isSecret,
            await provider.fetchValue(forKey: absoluteKey, type: type)
        )
        var conversionError: (any Error)?
        let finalResult: Result<(Value, Bool), any Error> = value.flatMap { configValue in
            if let configValue {
                do {
                    return .success((try unwrap(configValue.content), configValue.isSecret))
                } catch {
                    conversionError = error
                    return .failure(error)
                }
            } else {
                return .failure(ConfigError.missingRequiredConfigValue(absoluteKey))
            }
        }
        if let accessReporter {
            accessReporter.report(
                AccessEvent(
                    metadata: .init(
                        accessKind: .fetch,
                        key: absoluteKey,
                        valueType: type,
                        sourceLocation: .init(fileID: fileID, line: line),
                        accessTimestamp: .now
                    ),
                    providerResults: providerResults,
                    conversionError: conversionError,
                    result: finalResult.map { ConfigValue(wrap($0.0), isSecret: $0.1) }
                )
            )
        }
        return try finalResult.get().0
    }

    /// Watches for updates to a config value.
    ///
    /// - Parameters:
    ///   - key: The config key.
    ///   - type: The expected type of the config value.
    ///   - isSecret: Whether the value should be treated as secret.
    ///   - unwrap: A closure to extract the typed value from the raw config content.
    ///   - wrap: A closure to wrap the typed value back into config content.
    ///   - fileID: The source file identifier (used for event metadata).
    ///   - line: The line number (used for event metadata).
    ///   - updatesHandler: A closure that handles the stream of updates, emits `nil` when no value is found.
    /// - Throws: An error if the watch operation fails.
    /// - Returns: The value returned by the updates handler.
    internal func watchValue<Value: Sendable, Return: ~Copyable>(
        forKey key: ConfigKey,
        type: ConfigType,
        isSecret: Bool,
        unwrap: @Sendable @escaping (ConfigContent) throws -> Value,
        wrap: @Sendable @escaping (Value) -> ConfigContent,
        fileID: String,
        line: UInt,
        updatesHandler: (ConfigUpdatesAsyncSequence<Value?, Never>) async throws -> Return
    ) async throws -> Return {
        let absoluteKey = keyPrefix.appending(key)
        return try await provider.watchValue(forKey: absoluteKey, type: type) { updates in
            let mappedUpdates =
                updates
                .map { updateTuple in
                    let (providerResults, value) = mergingIsSecret(
                        isSecret,
                        updateTuple
                    )
                    let finalValue: (Value, Bool)?
                    let conversionError: (any Error)?

                    let configValue: ConfigValue?
                    do {
                        configValue = try value.get()
                    } catch {
                        // the error is surfaced through the `providerResults`
                        configValue = nil
                    }

                    do {
                        finalValue = try configValue.map { (try unwrap($0.content), $0.isSecret) }
                        conversionError = nil
                    } catch {
                        finalValue = nil
                        conversionError = error
                    }

                    if let accessReporter {
                        accessReporter.report(
                            AccessEvent(
                                metadata: .init(
                                    accessKind: .watch,
                                    key: absoluteKey,
                                    valueType: type,
                                    sourceLocation: .init(fileID: fileID, line: line),
                                    accessTimestamp: .now
                                ),
                                providerResults: providerResults,
                                conversionError: conversionError,
                                result: .success(
                                    finalValue.map { ConfigValue(wrap($0.0), isSecret: $0.1) }
                                )
                            )
                        )
                    }
                    return finalValue?.0
                }
            return try await updatesHandler(.init(mappedUpdates))
        }
    }

    /// Watches for updates to a config value, providing a default when missing.
    ///
    /// - Parameters:
    ///   - key: The config key.
    ///   - type: The expected type of the config value.
    ///   - isSecret: Whether the value should be treated as secret.
    ///   - defaultValue: The value to use when no config value is found.
    ///   - unwrap: A closure to extract the typed value from the raw config content.
    ///   - wrap: A closure to wrap the typed value back into config content.
    ///   - fileID: The source file identifier (used for event metadata).
    ///   - line: The line number (used for event metadata).
    ///   - updatesHandler: A closure that handles the stream of updates, emits the default when no value is found.
    /// - Throws: An error if the watch operation fails.
    /// - Returns: The value returned by the updates handler.
    internal func watchValue<Value: Sendable, Return: ~Copyable>(
        forKey key: ConfigKey,
        type: ConfigType,
        isSecret: Bool,
        default defaultValue: Value,
        unwrap: @Sendable @escaping (ConfigContent) throws -> Value,
        wrap: @Sendable @escaping (Value) -> ConfigContent,
        fileID: String,
        line: UInt,
        updatesHandler: (ConfigUpdatesAsyncSequence<Value, Never>) async throws -> Return
    ) async throws -> Return {
        let absoluteKey = keyPrefix.appending(key)
        return try await provider.watchValue(forKey: absoluteKey, type: type) { updates in
            let mappedUpdates =
                updates
                .map { updateTuple in
                    let (providerResults, value) = mergingIsSecret(
                        isSecret,
                        updateTuple
                    )
                    let finalValue: (Value, Bool)
                    let conversionError: (any Error)?

                    let configValue: ConfigValue?
                    do {
                        configValue = try value.get()
                    } catch {
                        // the error is surfaced through the `providerResults`
                        configValue = nil
                    }

                    do {
                        finalValue =
                            try configValue.map { (try unwrap($0.content), $0.isSecret) }
                            ?? (defaultValue, isSecret)
                        conversionError = nil
                    } catch {
                        finalValue = (defaultValue, isSecret)
                        conversionError = error
                    }

                    if let accessReporter {
                        accessReporter.report(
                            AccessEvent(
                                metadata: .init(
                                    accessKind: .watch,
                                    key: absoluteKey,
                                    valueType: type,
                                    sourceLocation: .init(fileID: fileID, line: line),
                                    accessTimestamp: .now
                                ),
                                providerResults: providerResults,
                                conversionError: conversionError,
                                result: .success(ConfigValue(wrap(finalValue.0), isSecret: finalValue.1))
                            )
                        )
                    }
                    return finalValue.0
                }
            return try await updatesHandler(.init(mappedUpdates))
        }
    }

    /// Watches for required config value updates.
    ///
    /// - Parameters:
    ///   - key: The config key.
    ///   - type: The expected type of the config value.
    ///   - isSecret: Whether the value should be treated as secret.
    ///   - unwrap: A closure to extract the typed value from the raw config content.
    ///   - wrap: A closure to wrap the typed value back into config content.
    ///   - fileID: The source file identifier (used for event metadata).
    ///   - line: The line number (used for event metadata).
    ///   - updatesHandler: A closure that handles the stream of updates, emits an error if the key is missing
    ///     or the value cannot be unwrapped.
    /// - Throws: An error if the watch operation fails.
    /// - Returns: The value returned by the updates handler.
    internal func watchRequiredValue<Value: Sendable, Return: ~Copyable>(
        forKey key: ConfigKey,
        type: ConfigType,
        isSecret: Bool,
        unwrap: @Sendable @escaping (ConfigContent) throws -> Value,
        wrap: @Sendable @escaping (Value) -> ConfigContent,
        fileID: String,
        line: UInt,
        updatesHandler: (ConfigUpdatesAsyncSequence<Value, any Error>) async throws -> Return
    ) async throws -> Return {
        let absoluteKey = keyPrefix.appending(key)
        return try await provider.watchValue(forKey: absoluteKey, type: type) { updates in
            let mappedUpdates =
                updates
                .mapThrowing { updateTuple in
                    let (providerResults, value) = mergingIsSecret(
                        isSecret,
                        updateTuple
                    )

                    let configValue = value.flatMap { configValue in
                        if let configValue {
                            .success(configValue)
                        } else {
                            .failure(ConfigError.missingRequiredConfigValue(absoluteKey))
                        }
                    }

                    var conversionError: (any Error)?
                    let finalResult: Result<(Value, Bool), any Error> = configValue.flatMap { configValue in
                        do {
                            return .success((try unwrap(configValue.content), configValue.isSecret))
                        } catch {
                            conversionError = error
                            return .failure(error)
                        }
                    }

                    if let accessReporter {
                        accessReporter.report(
                            AccessEvent(
                                metadata: .init(
                                    accessKind: .watch,
                                    key: absoluteKey,
                                    valueType: type,
                                    sourceLocation: .init(fileID: fileID, line: line),
                                    accessTimestamp: .now
                                ),
                                providerResults: providerResults,
                                conversionError: conversionError,
                                result: finalResult.map { ConfigValue(wrap($0.0), isSecret: $0.1) }
                            )
                        )
                    }
                    return try finalResult.get().0
                }
            return try await updatesHandler(.init(mappedUpdates))
        }
    }

    /// Casts a string into a config string convertible type.
    ///
    /// - Parameters:
    ///   - string: The string to cast.
    ///   - type: The target type.
    ///   - key: The config key.
    /// - Throws: A `ConfigError` if conversion fails.
    /// - Returns: The typed value.
    internal func cast<Value: ExpressibleByConfigString>(
        _ string: String,
        type: Value.Type,
        key: ConfigKey
    ) throws -> Value {
        guard let typedValue = Value.init(configString: string) else {
            throw ConfigError.configValueFailedToCast(name: keyPrefix.appending(key).description, type: "\(type)")
        }
        return typedValue
    }

    /// Casts a string into a raw representable type.
    ///
    /// - Parameters:
    ///   - string: The string to cast.
    ///   - type: The target type.
    ///   - key: The config key for error context.
    /// - Throws: A `ConfigError` if conversion fails.
    /// - Returns: The typed value.
    internal func cast<Value: RawRepresentable<String>>(
        _ string: String,
        type: Value.Type,
        key: ConfigKey
    ) throws -> Value {
        guard let typedValue = Value.init(rawValue: string) else {
            throw ConfigError.configValueFailedToCast(name: keyPrefix.appending(key).description, type: "\(type)")
        }
        return typedValue
    }

    /// Converts a string convertible type into raw config content.
    ///
    /// - Parameter value: The typed value.
    /// - Returns: The wrapped config content.
    internal func uncast<Value: ExpressibleByConfigString>(
        _ value: Value
    ) -> ConfigContent {
        .string(value.description)
    }

    /// Converts an array of string convertible values into raw config content.
    ///
    /// - Parameter values: The array of typed values to convert.
    /// - Returns: The wrapped config content as a string array.
    internal func uncast<Value: ExpressibleByConfigString>(
        _ values: [Value]
    ) -> ConfigContent {
        .stringArray(values.map(\.description))
    }

    /// Converts a raw representable type into raw config content.
    ///
    /// - Parameter value: The typed value with a string raw value.
    /// - Returns: The wrapped config content as a string.
    internal func uncast<Value: RawRepresentable<String>>(
        _ value: Value
    ) -> ConfigContent {
        .string(value.rawValue)
    }

    /// Converts an array of raw representable types into raw config content.
    ///
    /// - Parameter values: The array of typed values with string raw values to convert.
    /// - Returns: The wrapped config content as a string array.
    internal func uncast<Value: RawRepresentable<String>>(
        _ values: [Value]
    ) -> ConfigContent {
        .stringArray(values.map(\.rawValue))
    }
}
