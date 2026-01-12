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
            from: "1.0.0",
            traits: [.defaults, "CommandLineArguments"]
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
