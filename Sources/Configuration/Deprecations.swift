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
