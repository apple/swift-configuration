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
    let specifier: SecretsSpecifier<String, String> = .dynamic(@Sendable { _, _ in true })
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
}
