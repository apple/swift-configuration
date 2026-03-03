// swift-tools-version:6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "config-reload-example",
    platforms: [.macOS(.v15), .iOS(.v18), .tvOS(.v18)],
    products: [
        .executable(name: "App", targets: ["App"])
    ],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
        .package(url: "https://github.com/jpsim/Yams", from: "6.0.0"),
        .package(
            url: "https://github.com/apple/swift-configuration.git",
            from: "1.0.0",
            traits: [.defaults, "CommandLineArguments", "Reloading", "YAML"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "Configuration", package: "swift-configuration"),
                .product(name: "Hummingbird", package: "hummingbird"),
            ],
            path: "Sources/App"
        ),
        .testTarget(
            name: "AppTests",
            dependencies: [
                .byName(name: "App"),
                .product(name: "HummingbirdTesting", package: "hummingbird"),
            ],
            resources: [.process("Fixtures")]
        ),
    ]
)
