// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "hello-world-cli-example",
    platforms: [
        .macOS(.v15)
    ],
    dependencies: [
        .package(
            url: "https://github.com/apple/swift-configuration",
            // TODO: Update once 1.0.0 is tagged.
            exact: "1.0.0-alpha.1",
            traits: [.defaults, "CommandLineArgumentsSupport"]
        )
    ],
    targets: [
        .executableTarget(
            name: "CLI",
            dependencies: [
                .product(name: "Configuration", package: "swift-configuration")
            ]
        )
    ]
)
