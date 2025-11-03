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
import ConfigurationTestingInternal
@testable import Configuration
import Foundation
import ConfigurationTesting
import Logging
import Metrics
import ServiceLifecycle
import Synchronization
import SystemPackage

@available(Configuration 1.0, *)
private func withTestProvider<R>(
    body: (
        FileProvider<TestSnapshot>,
        InMemoryFileSystem,
        FilePath,
        Date
    ) async throws -> R
) async throws -> R {
    try await withTestFileSystem { fileSystem, filePath, originalTimestamp in
        let provider = try await FileProvider<TestSnapshot>(
            parsingOptions: .default,
            filePath: filePath,
            fileSystem: fileSystem
        )
        return try await body(provider, fileSystem, filePath, originalTimestamp)
    }
}

struct FileProviderTests {
    @available(Configuration 1.0, *)
    @Test func testLoad() async throws {
        try await withTestProvider { provider, fileSystem, filePath, originalTimestamp in
            // Check initial values
            let result1 = try provider.value(forKey: ["key1"], type: .string)
            #expect(try result1.value?.content.asString == "value1")
        }
    }
}
