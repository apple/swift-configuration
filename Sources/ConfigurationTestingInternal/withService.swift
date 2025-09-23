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

package import ServiceLifecycle

/// Manages the lifecycle of a service during test execution.
///
/// This function creates a service, runs it in the background, executes test work
/// with the service, and ensures proper cleanup by cancelling the service when done.
/// This pattern is essential for testing services that need to be running during
/// the test but should be properly torn down afterward.
///
/// ## Usage
///
/// Use this function to test services that need to be actively running:
///
/// ```swift
/// try await withService(createService: {
///     MyTestService()
/// }) { service in
///     // Perform tests with the running service
///     let result = try await service.performOperation()
///     return result
/// }
/// ```
///
/// - Parameters:
///   - createService: A closure that creates and returns the service instance.
///   - work: The test work to perform with the running service.
/// - Returns: The result produced by the work closure.
/// - Throws: Rethrows errors from service creation, service execution, or test work.
package func withService<S: Service, R>(createService: () async throws -> S, work: (S) async throws -> R) async throws
    -> R
{
    let service = try await createService()
    return try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            try await service.run()
        }
        defer {
            group.cancelAll()
        }
        return try await work(service)
    }
}
