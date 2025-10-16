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

struct AbsoluteConfigKeyTests {
    @Test func prependingSimpleKey() {
        let base = AbsoluteConfigKey(["bar", "baz"])
        let prefix = ConfigKey(["foo"])
        let result = base.prepending(prefix)

        #expect(result.components == ["foo", "bar", "baz"])
        #expect(result.context.isEmpty)
    }

    @Test func prependingWithContext() {
        let base = AbsoluteConfigKey(["bar"], context: ["env": .string("prod")])
        let prefix = ConfigKey(["foo"], context: ["region": .string("us-west")])
        let result = base.prepending(prefix)

        #expect(result.components == ["foo", "bar"])
        #expect(result.context["env"] == .string("prod"))
        #expect(result.context["region"] == .string("us-west"))
    }

    @Test func prependingWithConflictingContext() {
        let base = AbsoluteConfigKey(["bar"], context: ["key": .string("base-value")])
        let prefix = ConfigKey(["foo"], context: ["key": .string("prefix-value")])
        let result = base.prepending(prefix)

        #expect(result.components == ["foo", "bar"])
        #expect(result.context["key"] == .string("base-value"))
    }

    @Test func prependingEmptyKey() {
        let base = AbsoluteConfigKey(["foo", "bar"])
        let prefix = ConfigKey([])
        let result = base.prepending(prefix)

        #expect(result.components == ["foo", "bar"])
        #expect(result.context.isEmpty)
    }

    @Test func appendingSimpleKey() {
        let base = AbsoluteConfigKey(["foo", "bar"])
        let suffix = ConfigKey(["baz"])
        let result = base.appending(suffix)

        #expect(result.components == ["foo", "bar", "baz"])
        #expect(result.context.isEmpty)
    }

    @Test func appendingWithContext() {
        let base = AbsoluteConfigKey(["foo"], context: ["env": .string("prod")])
        let suffix = ConfigKey(["bar"], context: ["region": .string("us-west")])
        let result = base.appending(suffix)

        #expect(result.components == ["foo", "bar"])
        #expect(result.context["env"] == .string("prod"))
        #expect(result.context["region"] == .string("us-west"))
    }

    @Test func appendingWithConflictingContext() {
        let base = AbsoluteConfigKey(["foo"], context: ["key": .string("base-value")])
        let suffix = ConfigKey(["bar"], context: ["key": .string("suffix-value")])
        let result = base.appending(suffix)

        #expect(result.components == ["foo", "bar"])
        #expect(result.context["key"] == .string("suffix-value"))
    }

    @Test func appendingEmptyKey() {
        let base = AbsoluteConfigKey(["foo", "bar"])
        let suffix = ConfigKey([])
        let result = base.appending(suffix)

        #expect(result.components == ["foo", "bar"])
        #expect(result.context.isEmpty)
    }

    @Test func appendingMultipleKeys() {
        let base = AbsoluteConfigKey(["foo"])
        let result = base.appending(ConfigKey(["bar"])).appending(ConfigKey(["baz"]))

        #expect(result.components == ["foo", "bar", "baz"])
    }

    @Test func prependingMultipleKeys() {
        let base = AbsoluteConfigKey(["baz"])
        let result = base.prepending(ConfigKey(["bar"])).prepending(ConfigKey(["foo"]))

        #expect(result.components == ["foo", "bar", "baz"])
    }

    @Test func prependingAndAppending() {
        let base = AbsoluteConfigKey(["middle"])
        let result = base.prepending(ConfigKey(["start"])).appending(ConfigKey(["end"]))

        #expect(result.components == ["start", "middle", "end"])
    }
}
