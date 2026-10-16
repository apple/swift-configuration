# Integrating with Swift Argument Parser

Combine the commands and options of Swift Argument Parser with the provider hierarchy of Swift Configuration.

## Overview

[Swift Argument Parser](https://github.com/apple/swift-argument-parser) and Swift Configuration solve different problems, and you can use them together in the same tool.

Swift Argument Parser is the best choice when your tool reads its options directly, and you know all the options at compile time. It provides subcommands, generated help, input validation, and shell completion scripts.

Swift Configuration is more dynamic. Your application and the libraries it depends on read configuration through a ``ConfigReader``, including keys that aren't known at compile time. The values can come from sources, such as environment variables, files, and command line arguments.

``CommandLineArgumentsProvider`` is a convenience provider for when command line arguments are just one of several configuration sources. It doesn't support subcommands, positional arguments, or generated help, so on its own it works best for tools with a single command, such as a server with an implicit `serve` command.

When your tool has several commands, use Swift Argument Parser to define the commands and parse the command line, and use Swift Configuration to read the rest of your configuration. To make values from the command line available through a ``ConfigReader``, either map the options you declare to configuration keys, or forward the arguments that Swift Argument Parser doesn't recognize to a ``CommandLineArgumentsProvider``.

### Map parsed options to configuration keys

Declare the options in your command, and then add the values the user provides to an ``InMemoryProvider`` at the front of your provider hierarchy.
Your options keep the generated help and validation from Swift Argument Parser, and take precedence over values from the other providers:

```swift
import ArgumentParser
import Configuration

struct Serve: AsyncParsableCommand {
    @Option(help: "The port to listen on.")
    var port: Int?

    func run() async throws {
        var values: [AbsoluteConfigKey: ConfigValue] = [:]
        if let port {
            values["http.port"] = .init(.int(port), isSecret: false)
        }
        let config = ConfigReader(providers: [
            // First, check the options parsed from the command line.
            InMemoryProvider(name: "arguments", values: values),
            // Then, check environment variables.
            EnvironmentVariablesProvider(),
        ])

        // Uses `--port`, then `HTTP_PORT`, then the default value.
        let httpPort = config.int(forKey: "http.port", default: 8080)
        print(httpPort)
    }
}
```

> Tip: Declare the options as optional, without a default value. If you give an option a default value in Swift Argument Parser, that value always takes precedence over the values from the other providers.

### Forward unrecognized arguments

To accept any configuration key on the command line, without declaring an option for each one, capture the arguments that Swift Argument Parser doesn't recognize, and pass them to a ``CommandLineArgumentsProvider``.

This approach requires the `CommandLineArguments` package trait:

```swift
import ArgumentParser
import Configuration

struct Serve: AsyncParsableCommand {
    @Flag(help: "Enables verbose output.")
    var verbose = false

    @Argument(parsing: .allUnrecognized)
    var configArguments: [String] = []

    func run() async throws {
        let config = ConfigReader(providers: [
            // First, check the forwarded command line arguments.
            CommandLineArgumentsProvider(arguments: ["serve"] + configArguments),
            // Then, check environment variables.
            EnvironmentVariablesProvider(),
        ])

        // Program invoked with: `program serve --verbose --http-timeout 30`
        let httpTimeout = config.int(forKey: "http.timeout", default: 60)
        print(httpTimeout) // prints 30
    }
}
```

> Important: ``CommandLineArgumentsProvider`` expects the program name as the first element of `arguments`, and skips it.
> Insert a placeholder (such as "serve" above) before the forwarded arguments, as the example shows, otherwise the provider ignores the first forwarded argument.

### Choose an approach

Swift Argument Parser doesn't list forwarded arguments in the generated help, and doesn't report misspelled options, because it treats every argument it doesn't recognize as configuration.

Map parsed options for the options you know at compile time in your tool, and forward unrecognized arguments only for keys you can't declare in advance, such as the keys read by libraries used by your tool.

You can use both approaches in the same command.
