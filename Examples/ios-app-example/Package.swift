
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ios-app-example",
    platforms: [
        .iOS(.v13),
    ],
    products: [
        .executable(
            name: "ios-app-example",
            targets: ["ios-app-example"]
        ),
    ],
    dependencies: [
        .package(path: "../../"),
    ],
    targets: [
        .executableTarget(
            name: "ios-app-example",
            dependencies: [
                .product(name: "ConfigReader", package: "swift-configuration"),
            ]
        ),
    ]
)
