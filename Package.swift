// swift-tools-version: 6.1

import PackageDescription
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

let defaultTraits: Set<String> = [
    "JSONSupport"

    // Disabled due to a bug in SwiftPM with traits that pull in an external dependency.
    // Once that's fixed in Swift 6.2.x, we can enable these traits by default.
    // Open fix: https://github.com/swiftlang/swift-package-manager/pull/9136
    // "LoggingSupport",
    // "ReloadingSupport",
]

var traits: Set<Trait> = [
    .trait(
        name: "LoggingSupport",
        description: "Adds support for swift-log integration."
    ),
    .trait(
        name: "JSONSupport",
        description: "Adds support for parsing JSON configuration files."
    ),
    .trait(
        name: "ReloadingSupport",
        description:
            "Adds support for reloading built-in provider variants, such as ReloadingJSONProvider and ReloadingYAMLProvider (when their respective traits are enabled).",
        enabledTraits: [
            "LoggingSupport"
        ]
    ),
    .trait(
        name: "CommandLineArgumentsSupport",
        description: "Adds support for parsing command line arguments."
    ),
    .trait(
        name: "YAMLSupport",
        description: "Adds support for parsing YAML configuration files."
    ),
]

// Workaround to ensure that all traits are included in documentation. Swift Package Index adds
// SPI_GENERATE_DOCS (https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/2336)
// when building documentation, so only tweak the default traits in this condition.
let spiGenerateDocs = ProcessInfo.processInfo.environment["SPI_GENERATE_DOCS"] != nil

// Conditionally add the swift-docc plugin only when previewing docs locally.
// Preview with:
// ```
// SWIFT_PREVIEW_DOCS=1 swift package --disable-sandbox preview-documentation --target Configuration
// ```
let previewDocs = ProcessInfo.processInfo.environment["SWIFT_PREVIEW_DOCS"] != nil

// Enable all traits for other CI actions.
let enableAllTraitsExplicit = ProcessInfo.processInfo.environment["ENABLE_ALL_TRAITS"] != nil

let enableAllTraits = spiGenerateDocs || previewDocs || enableAllTraitsExplicit
let addDoccPlugin = previewDocs || spiGenerateDocs

traits.insert(
    .default(
        enabledTraits: enableAllTraits ? Set(traits.map(\.name)) : defaultTraits
    ),
)

let package = Package(
    name: "swift-configuration",
    products: [
        .library(name: "Configuration", targets: ["Configuration"]),
        .library(name: "ConfigurationTesting", targets: ["ConfigurationTesting"]),
    ],
    traits: traits,
    dependencies: [
        .package(url: "https://github.com/apple/swift-system", from: "1.5.0"),
        .package(url: "https://github.com/swift-server/swift-service-lifecycle", from: "2.7.0"),
        .package(url: "https://github.com/apple/swift-log", from: "1.6.3"),
        .package(url: "https://github.com/apple/swift-metrics", from: "2.7.0"),
        .package(url: "https://github.com/jpsim/Yams", "5.4.0"..<"7.0.0"),
    ],
    targets: [

        // Configuration library
        .target(
            name: "Configuration",
            dependencies: [
                .product(
                    name: "SystemPackage",
                    package: "swift-system"
                ),
                .product(
                    name: "Logging",
                    package: "swift-log",
                    condition: .when(traits: ["LoggingSupport"])
                ),
                .product(
                    name: "Metrics",
                    package: "swift-metrics",
                    condition: .when(traits: ["ReloadingSupport"])
                ),
                .product(
                    name: "ServiceLifecycle",
                    package: "swift-service-lifecycle",
                    condition: .when(traits: ["ReloadingSupport"])
                ),
                .product(
                    name: "Yams",
                    package: "Yams",
                    condition: .when(traits: ["YAMLSupport"])
                ),
            ],
            exclude: [
                "ConfigReader+methods.swift.gyb",
                "ConfigSnapshotReader+methods.swift.gyb",
            ]
        ),

        // Unit tests
        .testTarget(
            name: "ConfigurationTests",
            dependencies: [
                "Configuration",
                "ConfigurationTestingInternal",
                "ConfigurationTesting",
            ],
            exclude: [
                "ConfigReaderTests/ConfigReaderMethodTestsGet1.swift.gyb",
                "ConfigReaderTests/ConfigReaderMethodTestsGet2.swift.gyb",
                "ConfigReaderTests/ConfigReaderMethodTestsGet3.swift.gyb",
                "ConfigReaderTests/ConfigReaderMethodTestsFetch1.swift.gyb",
                "ConfigReaderTests/ConfigReaderMethodTestsFetch2.swift.gyb",
                "ConfigReaderTests/ConfigReaderMethodTestsFetch3.swift.gyb",
                "ConfigReaderTests/ConfigReaderMethodTestsWatch1.swift.gyb",
                "ConfigReaderTests/ConfigReaderMethodTestsWatch2.swift.gyb",
                "ConfigReaderTests/ConfigReaderMethodTestsWatch3.swift.gyb",
                "ConfigReaderTests/ConfigSnapshotReaderMethodTestsGet1.swift.gyb",
                "ConfigReaderTests/ConfigSnapshotReaderMethodTestsGet2.swift.gyb",
                "ConfigReaderTests/ConfigSnapshotReaderMethodTestsGet3.swift.gyb",
            ],
            resources: [
                .copy("Resources")
            ]
        ),

        // Testing (a public library)
        .target(
            name: "ConfigurationTesting",
            dependencies: [
                "Configuration",
                "ConfigurationTestingInternal",
            ]
        ),

        // Internals
        .target(
            name: "ConfigurationTestingInternal",
            dependencies: [
                "Configuration",
                .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
            ]
        ),
    ]
)

for target in package.targets {
    var settings = target.swiftSettings ?? []

    // https://github.com/apple/swift-evolution/blob/main/proposals/0335-existential-any.md
    // Require `any` for existential types.
    settings.append(.enableUpcomingFeature("ExistentialAny"))

    // https://github.com/swiftlang/swift-evolution/blob/main/proposals/0444-member-import-visibility.md
    settings.append(.enableUpcomingFeature("MemberImportVisibility"))

    // https://github.com/swiftlang/swift-evolution/blob/main/proposals/0409-access-level-on-imports.md
    settings.append(.enableUpcomingFeature("InternalImportsByDefault"))

    settings.append(.enableExperimentalFeature("AvailabilityMacro=Configuration 1.0:macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0"))

    target.swiftSettings = settings
}

if addDoccPlugin {
    package.dependencies.append(
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.0.0")
    )
}
