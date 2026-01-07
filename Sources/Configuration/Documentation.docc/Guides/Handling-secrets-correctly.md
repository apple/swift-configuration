# Handling secrets correctly

Protect sensitive configuration values from accidental disclosure in logs and debug output.

## Overview

Swift Configuration provides built-in support for marking sensitive values as secrets. Access reporters automatically redact secret values to prevent accidental disclosure of API keys, passwords, and other sensitive information.

### Marking values as secret when reading

Use the `isSecret` parameter on any configuration reader method to mark a value as secret:

```swift
let config = ConfigReader(provider: provider)

// Mark sensitive values as secret
let apiKey = try config.requiredString(
    forKey: "api.key",
    isSecret: true
)
let dbPassword = config.string(
    forKey: "database.password",
    isSecret: true
)

// Regular values don't need the parameter
let serverPort = try config.requiredInt(forKey: "server.port")
let logLevel = config.string(
    forKey: "log.level",
    default: "info"
)
```

This works with all access patterns and method variants:

```swift
// Works with fetch and watch too
let latestKey = try await config.fetchRequiredString(
   forKey: "api.key",
   isSecret: true
)

try await config.watchString(
    forKey: "api.key",
    isSecret: true
) { updates in
    for await key in updates {
        // Handle secret key updates
    }
}
```

### Provider-level secret specification

Use ``SecretsSpecifier`` to automatically mark values as secret based on keys or content when creating providers:

#### Mark all values as secret

The following example marks all configuration that the ``DirectoryFilesProvider`` reads as secret:

```swift
let provider = DirectoryFilesProvider(
    directoryPath: "/run/secrets",
    secretsSpecifier: .all
)
```

#### Mark specific keys as secret

The following example marks three specific keys from a provider as secret:

```swift
let provider = EnvironmentVariablesProvider(
    secretsSpecifier: .specific(["API_KEY", "DATABASE_PASSWORD", "JWT_SECRET"])
)
```

#### Dynamic secret detection

The following example marks keys as secret based on the closure you provide.
In this case, the library marks keys that contain `password`, `secret`, or `token` as secret:

```swift
let provider = FileProvider<JSONSnapshot>(
    filePath: "/etc/config.json",
    secretsSpecifier: .dynamic { key, value in
        key.lowercased().contains("password") ||
        key.lowercased().contains("secret") ||
        key.lowercased().contains("token")
    }
)
```

#### No secret values

The following example asserts that the provider doesn't return any secret values:

```swift
let provider = FileProvider<JSONSnapshot>(
    filePath: "/etc/config.json",
    secretsSpecifier: .none
)
```

### For provider implementors

When implementing a custom ``ConfigProvider``, use the ``ConfigValue`` type's `isSecret` property:

```swift
// Create a secret value
let secretValue = ConfigValue("sensitive-data", isSecret: true)

// Create a regular value  
let regularValue = ConfigValue("public-data", isSecret: false)
```

Set the `isSecret` property to `true` when your provider reads the values from a secrets store and must not log them.

### How the library protects secret values

The library automatically handles secret values with:

- **``AccessLogger``** and **``FileAccessLogger``**: Redact secret values in logs.
- **Provider descriptions**: Show `<REDACTED>` instead of actual values.

```swift
// This will show "<REDACTED>" for secret values
print(provider)
// "EnvironmentVariablesProvider[3 values: LOG_LEVEL=info, API_KEY=<REDACTED>, PORT=8080]"
```
> Warning: marking a configuration key as secret does not prevent you from exposing the secret directly.
> If you log values outside of using the ``AccessLogger`` or ``FileAccessLogger``, you may inadvertently expose the information.

### Best practices

1. **Mark all sensitive data as secret**: API keys, passwords, tokens, private keys, connection strings.
2. **Use provider-level specification** when you know which keys are always secret.
3. **Use reader-level marking** for context-specific secrets or when the same key might be secret in some contexts but not others.
4. **Be conservative**: When in doubt, mark values as secret. It's safer than accidentally leaking sensitive data.

For additional guidance on configuration security and overall best practices, see <doc:Best-practices>. To debug issues with secret redaction in access logs, check out <doc:Troubleshooting>. When selecting between required, optional, and default method variants for secret values, refer to <doc:Choosing-reader-methods>.
