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
#if canImport(FoundationEssentials)
package import FoundationEssentials
#else
package import Foundation
#endif
package import SystemPackage
import Synchronization

/// A simple in-memory file system used for testing.
@available(Configuration 1.0, *)
package final class InMemoryFileSystem: Sendable {

    /// Represents the type of data stored in the in-memory file system.
    ///
    /// Used to model both regular files and symbolic links.
    package enum FileData: Sendable {
        /// Represents a symbolic link to another file in the file system.
        /// - Parameter FilePath: The target location that this symlink points to.
        case symlink(FilePath)

        /// Represents a regular file with actual content.
        /// - Parameter Data: The raw binary content of the file.
        case file(Data)
    }

    /// Represents metadata and content information for a file in the in-memory file system.
    ///
    /// This struct combines both the file's content data and relevant metadata like modification time.
    package struct FileInfo: Sendable {
        /// The timestamp when the file was last modified.
        package var lastModifiedTimestamp: Date

        /// The actual content data of the file, either as regular file content or as a symbolic link.
        package var data: FileData

        package init(lastModifiedTimestamp: Date, data: FileData) {
            self.lastModifiedTimestamp = lastModifiedTimestamp
            self.data = data
        }
    }

    /// The files in the file system, keyed by file name.
    private let files: Mutex<[FilePath: FileInfo]>

    /// Creates a new in-memory file system with the given files.
    /// - Parameter files: The files in the file system, keyed by file path.
    package init(files: [FilePath: FileInfo]) {
        self.files = .init(files)
    }

    /// A test error.
    enum TestError: Error {
        /// The requested file was not found.
        case fileNotFound(filePath: FilePath)
    }

    /// Updates or adds a file in the in-memory file system with the specified content and timestamp.
    ///
    /// This method allows you to modify existing files or create new files in the file system.
    /// If a file already exists at the specified path, it will be completely replaced with the new data.
    /// If no file exists at the path, a new file entry will be created.
    ///
    /// - Parameters:
    ///   - filePath: The file path where the file should be stored or updated in the file system.
    ///   - timestamp: The last modified timestamp to associate with the file.
    ///   - contents: The file data to store, which can be either regular file content or a symbolic link.
    package func update(filePath: FilePath, timestamp: Date, contents: FileData) {
        files.withLock { files in
            files[filePath] = .init(lastModifiedTimestamp: timestamp, data: contents)
        }
    }

    /// Removes a file from the in-memory file system.
    ///
    /// This method deletes the file at the specified path from the file system.
    /// If the file does not exist, the operation completes silently without error.
    ///
    /// - Parameter filePath: The file path of the file to remove from the file system.
    package func remove(filePath: FilePath) {
        files.withLock { files in
            _ = files.removeValue(forKey: filePath)
        }
    }
}

@available(Configuration 1.0, *)
extension InMemoryFileSystem: CommonProviderFileSystem {
    func listFileNames(atPath directoryPath: FilePath) async throws -> [String]? {
        let prefixComponents = directoryPath.components
        let matchingFiles = files.withLock { files in
            files
                .filter { (filePath, _) in
                    let components = filePath.components
                    guard components.count == prefixComponents.count + 1 else {
                        return false
                    }
                    return Array(prefixComponents) == Array(components.dropLast())
                }
                .compactMap { $0.key.lastComponent?.string }
        }
        if matchingFiles.isEmpty {
            return nil
        }
        return matchingFiles
    }

    func lastModifiedTimestamp(atPath filePath: FilePath) async throws -> Date? {
        files.withLock { files in
            guard let data = files[filePath] else {
                return nil
            }
            return data.lastModifiedTimestamp
        }
    }

    func fileContents(atPath filePath: FilePath) async throws -> Data? {
        guard
            let data = files.withLock({ files -> FileInfo? in
                files[filePath]
            })
        else {
            return nil
        }
        switch data.data {
        case .file(let data):
            return data
        case .symlink(let target):
            return try await fileContents(atPath: target)
        }
    }

    func resolveSymlinks(atPath filePath: FilePath) async throws -> FilePath? {
        func locked_resolveSymlinks(at filePath: FilePath, files: inout [FilePath: FileInfo]) throws -> FilePath? {
            guard let data = files[filePath] else {
                return nil
            }
            switch data.data {
            case .file:
                return filePath
            case .symlink(let target):
                return try locked_resolveSymlinks(at: target, files: &files)
            }
        }
        return try files.withLock { files in
            try locked_resolveSymlinks(at: filePath, files: &files)
        }
    }
}
