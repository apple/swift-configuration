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

@testable import Configuration
import Testing

struct SeparatorKeyEncoderTests {
    @available(Configuration 1.0, *)
    @Test func dotEncoding() {
        let encoder: any ConfigKeyEncoder = .dotSeparated
        #expect(encoder.encode(.init(["foo"])) == "foo")
        #expect(encoder.encode(.init(["foo", "bar"])) == "foo.bar")
        #expect(encoder.encode(.init(["FOO", "BAR"])) == "FOO.BAR")
        #expect(encoder.encode(.init(["foo.bar"])) == "foo.bar")
    }

    @available(Configuration 1.0, *)
    @Test func dashEncoding() {
        let encoder: any ConfigKeyEncoder = .dashSeparated
        #expect(encoder.encode(.init(["foo"])) == "foo")
        #expect(encoder.encode(.init(["foo", "bar"])) == "foo-bar")
        #expect(encoder.encode(.init(["FOO", "BAR"])) == "FOO-BAR")
        #expect(encoder.encode(.init(["foo-bar"])) == "foo-bar")
    }
}
