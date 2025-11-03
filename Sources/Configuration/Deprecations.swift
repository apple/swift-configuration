/// A provider of configuration in JSON files.
@available(Configuration 1.0, *)
@available(*, deprecated, message: "Renamed to FileProvider<JSONSnapshot>")
public typealias JSONProvider = FileProvider<JSONSnapshot>

/// A reloading provider of configuration in JSON files.
@available(Configuration 1.0, *)
@available(*, deprecated, message: "Renamed to ReloadingFileProvider<JSONSnapshot>")
public typealias ReloadingJSONProvider = ReloadingFileProvider<JSONSnapshot>

/// A provider of configuration in YAML files.
@available(Configuration 1.0, *)
@available(*, deprecated, message: "Renamed to FileProvider<YAMLSnapshot>")
public typealias YAMLProvider = FileProvider<YAMLSnapshot>

/// A reloading provider of configuration in JSON files.
@available(Configuration 1.0, *)
@available(*, deprecated, message: "Renamed to ReloadingFileProvider<YAMLSnapshot>")
public typealias ReloadingYAMLProvider = ReloadingFileProvider<YAMLSnapshot>
