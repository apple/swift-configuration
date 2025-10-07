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

#if CommandLineArgumentsSupport

import Testing
@testable import Configuration

struct CLIArgumentParserTests {

    @available(Configuration 1.0, *)
    var parser: CLIArgumentParser {
        .init()
    }

    @available(Configuration 1.0, *)
    @Test func parsing() {
        #expect(parser.parse([]).isEmpty)
        #expect(parser.parse(["program"]).isEmpty)
        #expect(parser.parse(["program", "--verbose"]) == ["--verbose": []])
        #expect(parser.parse(["program", "--verbose", "--debug"]) == ["--verbose": [], "--debug": []])
        #expect(parser.parse(["program", "--host", "localhost"]) == ["--host": ["localhost"]])
        #expect(
            parser.parse(["program", "--host", "localhost", "--port", "8080"]) == [
                "--host": ["localhost"], "--port": ["8080"],
            ]
        )
        #expect(
            parser.parse(["program", "--servers", "server1", "server2", "server3"]) == [
                "--servers": ["server1", "server2", "server3"]
            ]
        )
        #expect(parser.parse(["program", "--port=8080"]) == ["--port": ["8080"]])
        #expect(parser.parse(["program", "--empty="]) == ["--empty": [""]])
        #expect(parser.parse(["program", "--tags", "a", "b", "c"]) == ["--tags": ["a", "b", "c"]])
        #expect(parser.parse(["program", "--tags", "a", "--tags", "b", "--tags", "c"]) == ["--tags": ["a", "b", "c"]])
        #expect(parser.parse(["program", "--tags", "a,b,c"]) == ["--tags": ["a", "b", "c"]])
        #expect(parser.parse(["program", "--tags", "a,b,,c"]) == ["--tags": ["a", "b", "", "c"]])
        #expect(parser.parse(["program", "--tags", "a,b", "--tags", "c"]) == ["--tags": ["a", "b", "c"]])
        #expect(parser.parse(["program", "--tags=a,b,c"]) == ["--tags": ["a", "b", "c"]])
        #expect(
            parser.parse(["program", "--verbose", "--host", "localhost", "--debug", "--ports", "8080", "8081"]) == [
                "--verbose": [], "--host": ["localhost"], "--debug": [], "--ports": ["8080", "8081"],
            ]
        )
        #expect(parser.parse(["program", "ignored", "--verbose"]) == ["--verbose": []])
        #expect(parser.parse(["program", "--input", "-"]) == ["--input": ["-"]])
        #expect(
            parser.parse(["program", "--url", "https://example.com/path?param=value"]) == [
                "--url": ["https://example.com/path?param=value"]
            ]
        )
    }
}

#endif
