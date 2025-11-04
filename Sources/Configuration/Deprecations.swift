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

#if JSONSupport
/// A provider of configuration in JSON files.
@available(Configuration 1.0, *)
@available(*, deprecated, message: "Renamed to FileProvider<JSONSnapshot>")
public typealias JSONProvider = FileProvider<JSONSnapshot>
#endif

#if YAMLSupport
/// A provider of configuration in YAML files.
@available(Configuration 1.0, *)
@available(*, deprecated, message: "Renamed to FileProvider<YAMLSnapshot>")
public typealias YAMLProvider = FileProvider<YAMLSnapshot>
#endif

#if ReloadingSupport

#if JSONSupport
/// A reloading provider of configuration in JSON files.
@available(Configuration 1.0, *)
@available(*, deprecated, message: "Renamed to ReloadingFileProvider<JSONSnapshot>")
public typealias ReloadingJSONProvider = ReloadingFileProvider<JSONSnapshot>
#endif

#if YAMLSupport
/// A reloading provider of configuration in JSON files.
@available(Configuration 1.0, *)
@available(*, deprecated, message: "Renamed to ReloadingFileProvider<YAMLSnapshot>")
public typealias ReloadingYAMLProvider = ReloadingFileProvider<YAMLSnapshot>
#endif

#endif

/// An immutable snapshot of a configuration provider's state.
@available(Configuration 1.0, *)
@available(*, deprecated, renamed: "ConfigSnapshot")
public typealias ConfigSnapshotProtocol = ConfigSnapshot
