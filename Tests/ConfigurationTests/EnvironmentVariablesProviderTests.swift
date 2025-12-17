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
import Foundation
import ConfigurationTestingInternal
import ConfigurationTesting
import SystemPackage

struct EnvironmentVariablesProviderTests {

    @available(Configuration 1.0, *)
    var provider: EnvironmentVariablesProvider {
        EnvironmentVariablesProvider(
            environmentVariables: [
                "STRING": "Hello",
                "OTHER_STRING": "Other Hello",
                "INT": "42",
                "OTHER_INT": "24",
                "DOUBLE": "3.14",
                "OTHER_DOUBLE": "2.72",
                "BOOL": "true",
                "OTHER_BOOL": "false",
                "BYTES": "bWFnaWM=",
                "OTHER_BYTES": "bWFnaWMy",
                "STRINGY_ARRAY": "Hello,World",
                "OTHER_STRINGY_ARRAY": "Hello,Swift",
                "INTY_ARRAY": "42,24",
                "OTHER_INTY_ARRAY": "16,32",
                "DOUBLY_ARRAY": "3.14,2.72",
                "OTHER_DOUBLY_ARRAY": "0.9,1.8",
                "BOOLY_ARRAY": "true,false",
                "OTHER_BOOLY_ARRAY": "false,true,true",
                "BYTE_CHUNKY_ARRAY": "bWFnaWM=,bWFnaWMy",
                "OTHER_BYTE_CHUNKY_ARRAY": "bWFnaWM=,bWFnaWMy,bWFnaWM=",
            ],
            secretsSpecifier: .specific([
                "STRING"
            ])
        )
    }

    @available(Configuration 1.0, *)
    @Test func printingDescription() throws {
        let expectedDescription = #"""
            EnvironmentVariablesProvider[20 values]
            """#
        #expect(provider.description == expectedDescription)
    }

    @available(Configuration 1.0, *)
    @Test func printingDebugDescription() throws {
        let expectedDebugDescription = #"""
            EnvironmentVariablesProvider[20 values: BOOL=true, BOOLY_ARRAY=true,false, BYTES=bWFnaWM=, BYTE_CHUNKY_ARRAY=bWFnaWM=,bWFnaWMy, DOUBLE=3.14, DOUBLY_ARRAY=3.14,2.72, INT=42, INTY_ARRAY=42,24, OTHER_BOOL=false, OTHER_BOOLY_ARRAY=false,true,true, OTHER_BYTES=bWFnaWMy, OTHER_BYTE_CHUNKY_ARRAY=bWFnaWM=,bWFnaWMy,bWFnaWM=, OTHER_DOUBLE=2.72, OTHER_DOUBLY_ARRAY=0.9,1.8, OTHER_INT=24, OTHER_INTY_ARRAY=16,32, OTHER_STRING=Other Hello, OTHER_STRINGY_ARRAY=Hello,Swift, STRING=<REDACTED>, STRINGY_ARRAY=Hello,World]
            """#
        #expect(provider.debugDescription == expectedDebugDescription)
    }

    @available(Configuration 1.0, *)
    @Test func valueForKeyOfBoolAndBoolArrayTypes() throws {
        let ep = EnvironmentVariablesProvider(
            environmentVariables: [
                "BOOL_TRUE": "true",
                "BOOL_FALSE": "false",
                "BOOL_1": "1",
                "BOOL_0": "0",
                "BOOL_YES": "YES",
                "BOOL_NO": "NO",
                "BOOL_THROWS_ERROR_EMPTY": "",
                "BOOL_THROWS_ERROR_NOT_BOOL_STRING": "2",
                "BOOLY_ARRAY_TRUE": "true,1,,YES",
                "BOOLY_ARRAY_FALSE": "false,0,NO",
                "BOOLY_ARRAY_THROWS_1": "true,1,YESS",
                "BOOLY_ARRAY_THROWS_2": "false,00,no",
            ])
        #expect(try ep.value(forKey: "BOOL_TRUE", type: .bool).value == true)
        #expect(try ep.value(forKey: "BOOL_FALSE", type: .bool).value == false)
        #expect(try ep.value(forKey: "BOOL_1", type: .bool).value == true)
        #expect(try ep.value(forKey: "BOOL_0", type: .bool).value == false)
        #expect(try ep.value(forKey: "BOOL_YES", type: .bool).value == true)
        #expect(try ep.value(forKey: "BOOL_NO", type: .bool).value == false)
        #expect(throws: ConfigError.self) { try ep.value(forKey: "BOOL_THROWS_ERROR_EMPTY", type: .bool) }
        #expect(throws: ConfigError.self) { try ep.value(forKey: "BOOL_THROWS_ERROR_NOT_BOOL_STRING", type: .bool) }
        #expect(try ep.value(forKey: "BOOLY_ARRAY_TRUE", type: .boolArray).value == .init([true, true, true], isSecret: false))
        #expect(try ep.value(forKey: "BOOLY_ARRAY_FALSE", type: .boolArray).value == .init([false, false, false], isSecret: false))
        #expect(throws: ConfigError.self) { try ep.value(forKey: "BOOLY_ARRAY_THROWS_1", type: .boolArray) }
        #expect(throws: ConfigError.self) { try ep.value(forKey: "BOOLY_ARRAY_THROWS_2", type: .boolArray) }
    }

    @available(Configuration 1.0, *)
    @Test func compat() async throws {
        try await ProviderCompatTest(provider: provider).runTest()
    }

    @available(Configuration 1.0, *)
    @Test func secretSpecifier() throws {
        #expect(try provider.value(forKey: ["string"], type: .string).value?.isSecret == true)
        #expect(try provider.value(forKey: ["other.string"], type: .string).value?.isSecret == false)
    }

    @available(Configuration 1.0, *)
    @Test func parseEnvironmentFile() throws {
        let values = EnvironmentFileParser.parsed(
            #"""
            # Start
            ENABLED=true
            HTTP_VERSION=2

               

            =invalid

            # This one is secret
            HTTP_SECRET=s3cret
            HTTP_CLIENT_TIMEOUT=15
            HTTP_CLIENT_USER_AGENT=Config/1.0 (Test)

            """#
        )
        let expected = [
            "ENABLED": "true",
            "HTTP_VERSION": "2",
            "HTTP_SECRET": "s3cret",
            "HTTP_CLIENT_TIMEOUT": "15",
            "HTTP_CLIENT_USER_AGENT": "Config/1.0 (Test)",
        ]
        #expect(values == expected)
    }

    @available(Configuration 1.0, *)
    @Test func loadEnvironmentFile() async throws {
        let fileSystem = InMemoryFileSystem(files: [
            "/etc/.env": .file(
                timestamp: .now,
                contents: """
                    HTTP_SECRET=s3cret
                    ENABLED=true

                    """
            )
        ])
        let provider = try await EnvironmentVariablesProvider(
            environmentFilePath: "/etc/.env",
            allowMissing: false,
            fileSystem: fileSystem,
            secretsSpecifier: .specific([
                "HTTP_SECRET"
            ])
        )
        let config = ConfigReader(provider: provider)
        #expect(config.bool(forKey: "enabled") == true)
        #expect(config.string(forKey: "http.secret") == "s3cret")
    }

    @available(Configuration 1.0, *)
    @Test func loadEnvironmentMissingError() async throws {
        let fileSystem = InMemoryFileSystem(files: [:])
        let envFilePath: FilePath = "/tmp/definitelyNotAnEnvFile"
        do {
            _ = try await EnvironmentVariablesProvider(
                environmentFilePath: envFilePath,
                allowMissing: false,
                fileSystem: fileSystem,
                secretsSpecifier: .specific([
                    "HTTP_SECRET"
                ])
            )
            #expect(Bool(false), "Initializer should have thrown an error")
        } catch let error as FileSystemError {
            guard case .fileNotFound(path: let path) = error else {
                #expect(Bool(false), "Initializer should have thrown an error")
                return
            }
            #expect(path == "/tmp/definitelyNotAnEnvFile")
        }
    }

    @available(Configuration 1.0, *)
    @Test func loadEnvironmentAllowedMissing() async throws {
        let fileSystem = InMemoryFileSystem(files: [:])
        let envFilePath: FilePath = "/tmp/definitelyNotAnEnvFile"
        _ = try await EnvironmentVariablesProvider(
            environmentFilePath: envFilePath,
            allowMissing: true,
            fileSystem: fileSystem
        )
    }
}

struct EnvironmentKeyEncoderTests {

    @available(Configuration 1.0, *)
    @Test func test() {
        let encoder = EnvironmentKeyEncoder()

        #expect(encoder.encode(["timeout"]) == "TIMEOUT")
        #expect(encoder.encode(["http.timeout"]) == "HTTP_TIMEOUT")
        #expect(encoder.encode(["http.serverTimeout"]) == "HTTP_SERVER_TIMEOUT")
        #expect(encoder.encode(["pollIntervalSeconds"]) == "POLL_INTERVAL_SECONDS")
    }
}
