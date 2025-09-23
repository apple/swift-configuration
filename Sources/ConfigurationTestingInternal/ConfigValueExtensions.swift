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

package import Configuration

extension [UInt8] {
    package static var magic: Self {
        [0x6d, 0x61, 0x67, 0x69, 0x63]
    }

    package static var magic2: Self {
        [0x6d, 0x61, 0x67, 0x69, 0x63, 0x32]
    }
}

extension ConfigValue {
    package static var magic: Self {
        ConfigValue(.bytes(.magic), isSecret: false)
    }

    package static var magic2: Self {
        ConfigValue(.bytes(.magic2), isSecret: false)
    }
}

extension ConfigValue {

    /// Creates a new string configuration value.
    /// - Parameters:
    ///   - value: The string value.
    ///   - isSecret: Whether the value contains sensitive information.
    package init(_ value: String, isSecret: Bool) {
        self.init(.string(value), isSecret: isSecret)
    }

    /// Creates a new integer configuration value.
    /// - Parameters:
    ///   - value: The integer value.
    ///   - isSecret: Whether the value contains sensitive information.
    package init(_ value: Int, isSecret: Bool) {
        self.init(.int(value), isSecret: isSecret)
    }

    /// Creates a new double configuration value.
    /// - Parameters:
    ///   - value: The double value.
    ///   - isSecret: Whether the value contains sensitive information.
    package init(_ value: Double, isSecret: Bool) {
        self.init(.double(value), isSecret: isSecret)
    }

    /// Creates a new boolean configuration value.
    /// - Parameters:
    ///   - value: The boolean value.
    ///   - isSecret: Whether the value contains sensitive information.
    package init(_ value: Bool, isSecret: Bool) {
        self.init(.bool(value), isSecret: isSecret)
    }

    /// Creates a new byte array configuration value.
    /// - Parameters:
    ///   - value: The byte array value.
    ///   - isSecret: Whether the value contains sensitive information.
    package init(_ value: [UInt8], isSecret: Bool) {
        self.init(.bytes(value), isSecret: isSecret)
    }

    /// Creates a new string array configuration value.
    /// - Parameters:
    ///   - value: The string array value.
    ///   - isSecret: Whether the value contains sensitive information.
    package init(_ value: [String], isSecret: Bool) {
        self.init(.stringArray(value), isSecret: isSecret)
    }

    /// Creates a new integer array configuration value.
    /// - Parameters:
    ///   - value: The integer array value.
    ///   - isSecret: Whether the value contains sensitive information.
    package init(_ value: [Int], isSecret: Bool) {
        self.init(.intArray(value), isSecret: isSecret)
    }

    /// Creates a new double array configuration value.
    /// - Parameters:
    ///   - value: The double array value.
    ///   - isSecret: Whether the value contains sensitive information.
    package init(_ value: [Double], isSecret: Bool) {
        self.init(.doubleArray(value), isSecret: isSecret)
    }

    /// Creates a new boolean array configuration value.
    /// - Parameters:
    ///   - value: The boolean array value.
    ///   - isSecret: Whether the value contains sensitive information.
    package init(_ value: [Bool], isSecret: Bool) {
        self.init(.boolArray(value), isSecret: isSecret)
    }

    /// Creates a new array of byte arrays configuration value.
    /// - Parameters:
    ///   - value: The array of byte arrays value.
    ///   - isSecret: Whether the value contains sensitive information.
    package init(_ value: [[UInt8]], isSecret: Bool) {
        self.init(.byteChunkArray(value), isSecret: isSecret)
    }
}
