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
import Foundation
@testable import Configuration

struct CLIKeyEncoderTests {

    let encoder = CLIKeyEncoder()

    @Test func encoding() {
        #expect(encoder.encode(["host"]) == "--host")
        #expect(encoder.encode(["app", "database", "host"]) == "--app-database-host")
        #expect(encoder.encode(["maxRetryCount"]) == "--max-retry-count")
        #expect(encoder.encode(["serverHTTP"]) == "--server-http")
        #expect(encoder.encode(["http2MaxStreams"]) == "--http2max-streams")
        #expect(encoder.encode(["httpAPITimeout"]) == "--http-apitimeout")
        #expect(encoder.encode(["httpServer", "connectionTimeout"]) == "--http-server-connection-timeout")
        #expect(encoder.encode(["HOST"]) == "--host")
        #expect(encoder.encode(["Database", "HOST"]) == "--database-host")
        #expect(encoder.encode(["a"]) == "--a")
        #expect(encoder.encode(["server1", "port8080"]) == "--server1-port8080")
        #expect(encoder.encode(["database_host"]) == "--database_host")
        #expect(encoder.encode(["user-agent"]) == "--user-agent")
        #expect(encoder.encode(["api.version"]) == "--api.version")

        // Note: This tests the encoder's behavior with empty components
        // In practice, empty components shouldn't occur in valid config keys
        #expect(encoder.encode([""]) == "--")
    }
}
