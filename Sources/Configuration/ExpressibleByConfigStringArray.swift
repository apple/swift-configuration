#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// A protocol for types that can be initialized from configuration string array values.
///
/// Conform your custom types to this protocol to enable automatic conversion from
/// string array configuration values using the `as:` parameter on `ConfigReader`.
///
/// This is useful for configuration values that are naturally represented as arrays of strings,
/// but require custom parsing to construct a single domain type (for example, HTTP header collections).
///
/// ## Custom types
///
/// For custom types that need to interpret the entire string array at once, conform to
/// ``ExpressibleByConfigStringArray`` by providing a failable initializer:
///
/// ```swift
/// struct HTTPHeaders: ExpressibleByConfigStringArray, CustomStringConvertible {
///     let headers: [(name: String, value: String)]
///
///     init?(configStringArray: [String]) {
///         var result: [(String, String)] = []
///
///         for item in configStringArray {
///             guard let colon = item.firstIndex(of: ":") else { return nil }
///
///             let name = item[..<colon]
///                 .trimmingCharacters(in: .whitespaces)
///
///             let value = item[item.index(after: colon)...]
///                 .trimmingCharacters(in: .whitespaces)
///
///             result.append((String(name), String(value)))
///         }
///
///         self.headers = result
///     }
///
///     var description: String {
///         "HTTPHeaders(\(headers.count))"
///     }
/// }
///
/// let config = ConfigReader(provider: EnvironmentVariablesProvider())
/// let headers = config.stringArray(forKey: "headers", as: HTTPHeaders.self)
/// ```
///
/// - Note: Unlike ``ExpressibleByConfigString``, this protocol is intended for types that
///   need to interpret the full string array to construct a single value.
@available(Configuration 1.0, *)
public protocol ExpressibleByConfigStringArray: CustomStringConvertible {

    /// Creates an instance from a configuration string array value.
    ///
    /// - Parameter configStringArray: The string array value from the configuration provider.
    init?(configStringArray: [String])
    
    /// Converts the value back into a configuration string array representation.
    var configStringArray: [String] { get }
}
