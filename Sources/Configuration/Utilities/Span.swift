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

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

@available(Configuration 1.0, *)
extension Data {
    /// Creates data from a raw span.
    /// - Parameter span: The raw span whose bytes to copy into a new Data.
    internal init(_ span: RawSpan) {
        self = span.withUnsafeBytes { pointer in
            guard let base = pointer.baseAddress else {
                return Data()
            }
            return Data(bytes: base, count: pointer.count)
        }
    }
}
