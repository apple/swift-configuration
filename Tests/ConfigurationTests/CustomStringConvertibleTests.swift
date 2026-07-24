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

import Testing
@testable import Configuration

struct CustomStringConvertibleTests {

  @available(Configuration 1.0, *)
  @Test func configKeyDebugDescription() {
    let key = ConfigKey(["http", "timeout"])
    #expect(key.description == "http.timeout")
    #expect(key.debugDescription == "http.timeout")
  }

  @available(Configuration 1.0, *)
  @Test func absoluteConfigKeyDebugDescription() {
    let key = AbsoluteConfigKey(["app", "feature", "enabled"])
    #expect(key.description == "app.feature.enabled")
    #expect(key.debugDescription == "app.feature.enabled")
  }

  @available(Configuration 1.0, *)
  @Test func configContextValueIntDebugDescription() {
    #expect(ConfigContextValue.int(8080).debugDescription == ".int(8080)")
  }

  @available(Configuration 1.0, *)
  @Test func configContextValueDoubleDebugDescription() {
    #expect(ConfigContextValue.double(1.5).debugDescription == ".double(1.5)")
  }

  @available(Configuration 1.0, *)
  @Test func configContextValueBoolDebugDescription() {
    #expect(ConfigContextValue.bool(true).debugDescription == ".bool(true)")
    #expect(ConfigContextValue.bool(false).debugDescription == ".bool(false)")
  }

  @available(Configuration 1.0, *)
  @Test func sourceLocationDescription() {
    let loc = AccessEvent.Metadata.SourceLocation(fileID: "MyModule/Config.swift", line: 99)
    #expect(loc.description == "MyModule/Config.swift:99")
    #expect(loc.debugDescription == "MyModule/Config.swift:99")
  }

  @available(Configuration 1.0, *)
  @Test func secretsSpecifierAllDescription() {
    let specifier: SecretsSpecifier<String, String> = .all
    #expect(specifier.description == "all")
    #expect(specifier.debugDescription == "all")
  }

  @available(Configuration 1.0, *)
  @Test func secretsSpecifierNoneDescription() {
    let specifier: SecretsSpecifier<String, String> = .none
    #expect(specifier.description == "none")
    #expect(specifier.debugDescription == "none")
  }

  @available(Configuration 1.0, *)
  @Test func secretsSpecifierSpecificDescription() {
    let specifier: SecretsSpecifier<String, String> = .specific(["apiKey", "token", "password"])
    #expect(specifier.description == "specific(3 keys)")
    #expect(specifier.debugDescription == "specific(3 keys)")
  }

  @available(Configuration 1.0, *)
  @Test func secretsSpecifierDynamicDescription() {
    let isSensitive: @Sendable (String, String) -> Bool = { _, _ in true }
    let specifier: SecretsSpecifier<String, String> = .dynamic(isSensitive)
    #expect(specifier.description == "dynamic")
    #expect(specifier.debugDescription == "dynamic")
  }

  @available(Configuration 1.0, *)
  @Test func configBytesFromBase64StringDecoderDescription() {
    let decoder = ConfigBytesFromBase64StringDecoder()
    #expect(decoder.description == "ConfigBytesFromBase64StringDecoder")
    #expect(decoder.debugDescription == "ConfigBytesFromBase64StringDecoder")
  }

  @available(Configuration 1.0, *)
  @Test func configBytesFromHexStringDecoderDescription() {
    let decoder = ConfigBytesFromHexStringDecoder()
    #expect(decoder.description == "ConfigBytesFromHexStringDecoder")
    #expect(decoder.debugDescription == "ConfigBytesFromHexStringDecoder")
  }

  @available(Configuration 1.0, *)
  @Test func configValueDescription() {
    let value = ConfigValue(.string("localhost"), isSecret: false)
    #expect(value.description == "[string: localhost]")
    #expect(value.debugDescription == "[string: localhost]")
  }

  @available(Configuration 1.0, *)
  @Test func configValueSecretDescription() {
    let secret = ConfigValue(.string("sk-abc123"), isSecret: true)
    #expect(secret.description == "[string: <REDACTED>]")
    #expect(secret.debugDescription == "[string: <REDACTED>]")
  }

  @available(Configuration 1.0, *)
  @Test func lookupResultFoundDescription() {
    let value = ConfigValue(.string("localhost"), isSecret: false)
    let result = LookupResult(encodedKey: "db.host", value: value)
    #expect(result.description == "[key: db.host, [string: localhost]]")
    #expect(result.debugDescription == "[key: db.host, [string: localhost]]")
  }

  @available(Configuration 1.0, *)
  @Test func lookupResultNotFoundDescription() {
    let result = LookupResult(encodedKey: "db.host", value: nil)
    #expect(result.description == "[key: db.host, (not found)]")
    #expect(result.debugDescription == "[key: db.host, (not found)]")
  }

  @available(Configuration 1.0, *)
  @Test func accessEventMetadataDescription() {
    let key = AbsoluteConfigKey(["db", "host"])
    let loc = AccessEvent.Metadata.SourceLocation(fileID: "MyModule/Config.swift", line: 99)
    let metadata = AccessEvent.Metadata(
      accessKind: .get,
      key: key,
      valueType: .string,
      sourceLocation: loc,
      accessTimestamp: Date()
    )
    // description omits source location; debugDescription includes it
    #expect(metadata.description == "get db.host as string")
    #expect(metadata.debugDescription == "get db.host as string @ MyModule/Config.swift:99")
  }

  @available(Configuration 1.0, *)
  @Test func accessEventProviderResultDescription() {
    let value = ConfigValue(.string("localhost"), isSecret: false)
    let lookup = LookupResult(encodedKey: "db.host", value: value)
    let providerResult = AccessEvent.ProviderResult(
      providerName: "InMemoryProvider",
      result: .success(lookup)
    )
    #expect(providerResult.description == "InMemoryProvider: [key: db.host, [string: localhost]]")
    #expect(providerResult.debugDescription == "InMemoryProvider: [key: db.host, [string: localhost]]")
  }

  @available(Configuration 1.0, *)
  @Test func accessEventProviderResultSecretDescription() {
    let secret = ConfigValue(.string("sk-abc123"), isSecret: true)
    let lookup = LookupResult(encodedKey: "api.key", value: secret)
    let providerResult = AccessEvent.ProviderResult(
      providerName: "InMemoryProvider",
      result: .success(lookup)
    )
    // secrets are redacted even inside provider results
    #expect(providerResult.description == "InMemoryProvider: [key: api.key, [string: <REDACTED>]]")
  }

  @available(Configuration 1.0, *)
  @Test func accessEventDescription() {
    let key = AbsoluteConfigKey(["db", "host"])
    let loc = AccessEvent.Metadata.SourceLocation(fileID: "MyModule/Config.swift", line: 99)
    let metadata = AccessEvent.Metadata(
      accessKind: .get,
      key: key,
      valueType: .string,
      sourceLocation: loc,
      accessTimestamp: Date()
    )
    let value = ConfigValue(.string("localhost"), isSecret: false)
    let lookup = LookupResult(encodedKey: "db.host", value: value)
    let providerResult = AccessEvent.ProviderResult(
      providerName: "InMemoryProvider[ 0 values]",
      result: .success(lookup)
    )
    let event = AccessEvent(
      metadata: metadata,
      providerResults: [providerResult],
      result: .success(value)
    )
    // description omits source location and provider details
    #expect(event.description == "AccessEvent[get db.host as string, result: [string: localhost]]")
    // debugDescription includes source location and per-provider breakdown
    #expect(
      event.debugDescription
        == "AccessEvent[get db.host as string @ MyModule/Config.swift:99, providers: [InMemoryProvider[ 0 values]: [key: db.host, [string: localhost]]], result: [string: localhost]]"
    )
  }

  @available(Configuration 1.0, *)
  @Test func configReaderDescription() {
    let reader = ConfigReader(provider: InMemoryProvider(values: [:]))
    #expect(reader.description == "ConfigReader[InMemoryProvider[ 0 values]]")
    #expect(reader.debugDescription == "ConfigReader[InMemoryProvider[ 0 values]]")
  }

  @available(Configuration 1.0, *)
  @Test func configReaderScopedDescription() {
    let reader = ConfigReader(provider: InMemoryProvider(values: [:])).scoped(to: "http")
    #expect(reader.description == "ConfigReader[prefix: http, InMemoryProvider[ 0 values]]")
    #expect(reader.debugDescription == "ConfigReader[prefix: http, InMemoryProvider[ 0 values]]")
  }

  @available(Configuration 1.0, *)
  @Test func configSnapshotReaderDescription() {
    let reader = ConfigReader(provider: InMemoryProvider(name: "test", values: [:]))
    let snapshotReader = reader.snapshot()
    #expect(snapshotReader.description == "ConfigSnapshotReader[of: InMemoryProvider[test]]")
    #expect(snapshotReader.debugDescription == "ConfigSnapshotReader[of: InMemoryProvider[test]]")
  }

  @available(Configuration 1.0, *)
  @Test func broadcastingAccessReporterDescription() {
    struct NoOpReporter: AccessReporter {
      func report(_ event: AccessEvent) {}
    }
    let reporter = BroadcastingAccessReporter(upstreams: [NoOpReporter(), NoOpReporter()])
    #expect(reporter.description == "BroadcastingAccessReporter[2 reporters]")
    #expect(reporter.debugDescription == "BroadcastingAccessReporter[2 reporters]")
  }
}
