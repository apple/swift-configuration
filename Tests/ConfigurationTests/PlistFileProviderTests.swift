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

#if Plist

import Testing
import ConfigurationTestingInternal
@testable import Configuration
import Foundation
import ConfigurationTesting
import SystemPackage

let plistTestFileContents = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
        <key>string</key>
        <string>Hello</string>
        <key>int</key>
        <integer>42</integer>
        <key>double</key>
        <real>3.14</real>
        <key>bool</key>
        <true/>
        <key>bytes</key>
        <data>bWFnaWM=</data>

        <key>other</key>
        <dict>
            <key>string</key>
            <string>Other Hello</string>
            <key>int</key>
            <integer>24</integer>
            <key>double</key>
            <real>2.72</real>
            <key>bool</key>
            <false/>
            <key>bytes</key>
            <data>bWFnaWMy</data>

            <key>stringy</key>
            <dict>
                <key>array</key>
                <array>
                    <string>Hello</string>
                    <string>Swift</string>
                </array>
            </dict>
            <key>inty</key>
            <dict>
                <key>array</key>
                <array>
                    <integer>16</integer>
                    <integer>32</integer>
                </array>
            </dict>
            <key>doubly</key>
            <dict>
                <key>array</key>
                <array>
                    <real>0.9</real>
                    <real>1.8</real>
                </array>
            </dict>
            <key>booly</key>
            <dict>
                <key>array</key>
                <array>
                    <false/>
                    <true/>
                    <true/>
                </array>
            </dict>
            <key>byteChunky</key>
            <dict>
                <key>array</key>
                <array>
                    <data>bWFnaWM=</data>
                    <data>bWFnaWMy</data>
                    <data>bWFnaWM=</data>
                </array>
            </dict>
        </dict>

        <key>stringy</key>
        <dict>
            <key>array</key>
            <array>
                <string>Hello</string>
                <string>World</string>
            </array>
        </dict>
        <key>inty</key>
        <dict>
            <key>array</key>
            <array>
                <integer>42</integer>
                <integer>24</integer>
            </array>
        </dict>
        <key>doubly</key>
        <dict>
            <key>array</key>
            <array>
                <real>3.14</real>
                <real>2.72</real>
            </array>
        </dict>
        <key>booly</key>
        <dict>
            <key>array</key>
            <array>
                <true/>
                <false/>
            </array>
        </dict>
        <key>byteChunky</key>
        <dict>
            <key>array</key>
            <array>
                <data>bWFnaWM=</data>
                <data>bWFnaWMy</data>
            </array>
        </dict>
    </dict>
    </plist>
    """

struct PlistFileProviderTests {

    @available(Configuration 1.0, *)
    var provider: PlistSnapshot {
        get throws {
            try PlistSnapshot(
                data: Data(plistTestFileContents.utf8).bytes,
                providerName: "TestProvider",
                parsingOptions: .default
            )
        }
    }

    @available(Configuration 1.0, *)
    @Test func printingDescription() async throws {
        let expectedDescription = #"""
            TestProvider[20 values]
            """#
        try #expect(provider.description == expectedDescription)
    }

    @available(Configuration 1.0, *)
    @Test func printingDebugDescription() async throws {
        let expectedDebugDescription = #"""
            TestProvider[20 values: bool=1, booly.array=1,0, byteChunky.array=bWFnaWM=,bWFnaWMy, bytes=bWFnaWM=, double=3.14, doubly.array=3.14,2.72, int=42, inty.array=42,24, other.bool=0, other.booly.array=0,1,1, other.byteChunky.array=bWFnaWM=,bWFnaWMy,bWFnaWM=, other.bytes=bWFnaWMy, other.double=2.72, other.doubly.array=0.9,1.8, other.int=24, other.inty.array=16,32, other.string=Other Hello, other.stringy.array=Hello,Swift, string=Hello, stringy.array=Hello,World]
            """#
        try #expect(provider.debugDescription == expectedDebugDescription)
    }

    @available(Configuration 1.0, *)
    @Test func compat() async throws {
        let fileSystem = InMemoryFileSystem(files: [
            "/etc/config.plist": .file(timestamp: .now, contents: plistTestFileContents)
        ])
        try await ProviderCompatTest(
            provider: FileProvider<PlistSnapshot>(
                parsingOptions: .default,
                filePath: "/etc/config.plist",
                allowMissing: false,
                fileSystem: fileSystem
            )
        )
        .runTest()
    }
}

#endif
