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
import Configuration

struct ExpressibleByConfigIntTests {
    struct MyDuration: ExpressibleByConfigInt, Equatable, CustomStringConvertible {
        let duration: Duration

        init?(configInt: Int) {
            self.duration = .seconds(configInt)
        }

        var description: String {
            duration.description
        }
    }

    enum TestIntEnum: Int, RawRepresentable, Equatable {
        case foo, bar
    }

    @available(Configuration 1.0, *)
    @Test func testExpressibleByConfigInt() throws {
        let provider = InMemoryProvider(
            values: [
                "server": 10,
                "timeouts": 5,
                "duration": 42,
                "durations": .init(.intArray([0, 1]), isSecret: false),
            ]
        )
        let config = ConfigReader(provider: provider)
        let timeouts = try #require(config.intArray(forKey: ["server", "timeouts"], as: MyDuration.self))
        #expect(timeouts == [.init(configInt: 10)!, .init(configInt: 5)!])

        let duration = config.int(forKey: "duration", as: MyDuration.self)
        #expect(duration == MyDuration(configInt: 42))

        let durations = config.intArray(forKey: "durations", as: TestIntEnum.self, isSecret: false)
        #expect(durations == [.bar, .foo])
    }
}
