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
import SystemPackage

/// This type only exists to test that deprecated symbols are still usable.
@available(Configuration 1.0, *)
@available(*, deprecated)
struct Deprecations {
    #if ReloadingSupport && JSONSupport && YAMLSupport
    func fileProviders() async throws {
        let _ = try await JSONProvider(filePath: "/dev/null")
        let _ = try await ReloadingJSONProvider(filePath: "/dev/null")
        let _ = try await YAMLProvider(filePath: "/dev/null")
        let _ = try await ReloadingYAMLProvider(filePath: "/dev/null")
    }
    #endif
}
