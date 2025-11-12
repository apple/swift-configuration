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

import SystemPackage
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Prints a string to the standard error stream.
///
/// - Parameter string: The string to write to standard error.
func printToStderr(_ string: String) {
    let message = string + "\n"
    _ = try? FileDescriptor.standardError.writeAll(message.utf8)
}

@available(Configuration 1.0, *)
extension StringProtocol {
    /// Returns the contents of the string with any whitespace prefix and suffix trimmed.
    /// - Returns: The trimmed string.
    internal func trimmed() -> String {
        String(trimmingPrefix(while: \.isWhitespace).reversed().trimmingPrefix(while: \.isWhitespace).reversed())
    }
}

extension Error {
    /// Inspects whether the error represents a file not found.
    internal var isFileNotFoundError: Bool {
        if let posixError = self as? POSIXError {
            return posixError.code == POSIXError.Code.ENOENT
        }
        if let cocoaError = self as? CocoaError, cocoaError.isFileError {
            return [
                CocoaError.fileNoSuchFile,
                CocoaError.fileReadNoSuchFile,
            ]
            .contains(cocoaError.code)
        }
        return false
    }
}
