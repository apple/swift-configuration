// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "hello-world-cli-example",
    platforms: [
        .macOS(.v15)
    ],
    dependencies: [
       .package(url: "https://github.com/apple/swift-configuration", .upToNextMinor(from: "0.1.0"), traits: [.defaults, "CommandLineArgumentsSupport"])
    ],
    targets: [
        .executableTarget(
            name: "CLI",
            dependencies: [
                .product(name: "Configuration", package: "swift-configuration"),
            ]
        ),
    ]
)
