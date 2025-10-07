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
package import FoundationEssentials
#else
package import Foundation
#endif
package import SystemPackage

/// A file system abstraction used by some of the providers in Configuration.
@available(Configuration 1.0, *)
package protocol CommonProviderFileSystem: Sendable {
    /// Loads the file contents at the specified file path.
    /// - Parameter filePath: The path to the file.
    /// - Returns: The byte contents of the file.
    /// - Throws: When the file cannot be read.
    func fileContents(atPath filePath: FilePath) async throws -> Data

    /// Reads the last modified timestamp of the file, if it exists.
    /// - Parameter filePath: The file path to check.
    /// - Returns: The last modified timestamp, if found. Nil if the file is not found.
    /// - Throws: When any other attribute reading error occurs.
    func lastModifiedTimestamp(atPath filePath: FilePath) async throws -> Date

    /// Lists all regular file names in the specified directory.
    /// - Parameter directoryPath: The path to the directory.
    /// - Returns: An array of file names in the directory.
    /// - Throws: When the directory cannot be read or doesn't exist.
    func listFileNames(atPath directoryPath: FilePath) async throws -> [String]

    /// Resolves symlinks and returns the real file path.
    ///
    /// If the provided path is not a symlink, returns the same unmodified path.
    /// - Parameter filePath: The file path that may contain symlinks.
    /// - Returns: The resolved file path with symlinks resolved.
    /// - Throws: When the path cannot be resolved.
    func resolveSymlinks(atPath filePath: FilePath) async throws -> FilePath
}

/// A file system implementation that uses the local file system.
@available(Configuration 1.0, *)
package struct LocalCommonProviderFileSystem: Sendable {
    /// The error thrown by the file system.
    package enum FileSystemError: Error, CustomStringConvertible {
        /// The directory was not found at the provided path.
        case directoryNotFound(path: FilePath)

        /// Failed to read a file in the directory.
        case fileReadError(filePath: FilePath, underlyingError: any Error)

        /// Failed to read a file in the directory.
        case missingLastModifiedTimestampAttribute(filePath: FilePath)

        /// The path exists but is not a directory.
        case notADirectory(path: FilePath)

        package var description: String {
            switch self {
            case .directoryNotFound(let path):
                return "Directory not found at path: \(path)."
            case .fileReadError(let filePath, let error):
                return "Failed to read file '\(filePath)': \(error)."
            case .missingLastModifiedTimestampAttribute(let filePath):
                return "Missing last modified timestamp attribute for file '\(filePath)."
            case .notADirectory(let path):
                return "Path exists but is not a directory: \(path)."
            }
        }
    }
}

@available(Configuration 1.0, *)
extension LocalCommonProviderFileSystem: CommonProviderFileSystem {
    package func fileContents(atPath filePath: FilePath) async throws -> Data {
        do {
            return try Data(contentsOf: URL(filePath: filePath.string))
        } catch {
            throw FileSystemError.fileReadError(
                filePath: filePath,
                underlyingError: error
            )
        }
    }

    package func lastModifiedTimestamp(atPath filePath: FilePath) async throws -> Date {
        guard
            let timestamp = try FileManager().attributesOfItem(atPath: filePath.string)[.modificationDate]
                as? Date
        else {
            throw FileSystemError.missingLastModifiedTimestampAttribute(filePath: filePath)
        }
        return timestamp
    }

    package func listFileNames(atPath directoryPath: FilePath) async throws -> [String] {
        let fileManager = FileManager.default
        #if canImport(Darwin)
        var isDirectoryWrapper: ObjCBool = false
        #else
        var isDirectoryWrapper: Bool = false
        #endif
        guard fileManager.fileExists(atPath: directoryPath.string, isDirectory: &isDirectoryWrapper) else {
            throw FileSystemError.directoryNotFound(path: directoryPath)
        }
        #if canImport(Darwin)
        let isDirectory = isDirectoryWrapper.boolValue
        #else
        let isDirectory = isDirectoryWrapper
        #endif
        guard isDirectory else {
            throw FileSystemError.notADirectory(path: directoryPath)
        }
        return
            try fileManager
            .contentsOfDirectory(atPath: directoryPath.string)
            .filter { !$0.hasPrefix(".") }
            .compactMap { (fileName) -> String? in
                // Skip non-regular files (directories, symlinks, etc.)
                let attributes =
                    try fileManager
                    .attributesOfItem(atPath: directoryPath.appending(fileName).string)
                guard let type = (attributes[.type] as? FileAttributeType), type == FileAttributeType.typeRegular else {
                    return nil
                }
                return fileName
            }
    }

    package func resolveSymlinks(atPath filePath: FilePath) async throws -> FilePath {
        FilePath(URL(filePath: filePath.string).resolvingSymlinksInPath().path())
    }
}
