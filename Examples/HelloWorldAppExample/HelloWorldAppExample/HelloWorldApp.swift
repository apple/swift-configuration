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

import Configuration
import SwiftUI

@main
struct HelloWorldAppExampleApp: App {
    let greetedName: String

    init() {
        let config = ConfigReader(providers: [
            EnvironmentVariablesProvider(),
            InMemoryProvider(values: ["greetedName": "Memory"]),
        ])
        greetedName = config.string(forKey: "greetedName", default: "World")
    }

    var body: some Scene {
        WindowGroup {
            HelloWorldView(greetedName: greetedName)
        }
    }
}
