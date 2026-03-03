// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Benchmarks",
    platforms: [
        .macOS(.v15)
    ],
    dependencies: [
        .package(path: "../"),
        .package(url: "https://github.com/ordo-one/package-benchmark.git", from: "1.29.6"),
    ],
    targets: [
        .executableTarget(
            name: "Benchmarks",
            dependencies: [
                .product(name: "Benchmark", package: "package-benchmark"),
                .product(name: "Configuration", package: "swift-configuration"),
            ],
            path: "Sources",
            plugins: [
                .plugin(name: "BenchmarkPlugin", package: "package-benchmark")
            ]
        )
    ]
)
