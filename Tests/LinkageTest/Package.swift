// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "linkage-test",
    platforms: [
        .macOS(.v15), .iOS(.v18), .macCatalyst(.v18), .tvOS(.v18), .watchOS(.v11), .visionOS(.v2),
    ],
    dependencies: [
        // Disable default traits to show that it's possible to link the core library without full Foundation on Linux.
        .package(name: "swift-configuration", path: "../..", traits: [])
    ],
    targets: [
        .executableTarget(
            name: "configurationLinkageTest",
            dependencies: [
                .product(name: "Configuration", package: "swift-configuration")
            ]
        )
    ]
)

for target in package.targets {
    if target.type != .plugin {
        var settings = target.swiftSettings ?? []

        // https://github.com/apple/swift-evolution/blob/main/proposals/0335-existential-any.md
        // Require `any` for existential types.
        settings.append(.enableUpcomingFeature("ExistentialAny"))

        // https://github.com/swiftlang/swift-evolution/blob/main/proposals/0444-member-import-visibility.md
        settings.append(.enableUpcomingFeature("MemberImportVisibility"))

        // https://github.com/swiftlang/swift-evolution/blob/main/proposals/0409-access-level-on-imports.md
        settings.append(.enableUpcomingFeature("InternalImportsByDefault"))

        target.swiftSettings = settings
    }
}
