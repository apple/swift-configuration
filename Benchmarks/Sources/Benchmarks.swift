//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftConfiguration open source project
//
// Copyright (c) 2025 Apple Inc. and the SwiftConfiguration project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftConfiguration project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Benchmark
import Configuration
import Foundation

let benchmarks: @Sendable () -> Void = {
    let defaultMetrics: [BenchmarkMetric] = [
        .mallocCountTotal,
        // .contextSwitches,
        // .wallClock,
    ]

    Benchmark(
        "ConfigReader_InMemoryProvider_notFound_string",
        configuration: Benchmark.Configuration(
            metrics: defaultMetrics,
            scalingFactor: .kilo
        )
    ) { benchmark in
        let emptyReader = ConfigReader(provider: InMemoryProvider(values: [:]))
        for _ in benchmark.scaledIterations {
            blackHole(emptyReader.string(forKey: "foo"))
        }
    }

    Benchmark(
        "ConfigReader_InMemoryProvider_found_string",
        configuration: Benchmark.Configuration(
            metrics: defaultMetrics,
            scalingFactor: .kilo
        )
    ) { benchmark in
        let emptyReader = ConfigReader(provider: InMemoryProvider(values: ["foo": "bar"]))
        for _ in benchmark.scaledIterations {
            blackHole(emptyReader.string(forKey: "foo"))
        }
    }

    Benchmark(
        "ConfigReader_InMemoryProvider_found_int",
        configuration: Benchmark.Configuration(
            metrics: defaultMetrics,
            scalingFactor: .kilo
        )
    ) { benchmark in
        let emptyReader = ConfigReader(provider: InMemoryProvider(values: ["foo": 24]))
        for _ in benchmark.scaledIterations {
            blackHole(emptyReader.int(forKey: "foo"))
        }
    }

    Benchmark(
        "ConfigReader_InMemoryProvider_found_fetchInt",
        configuration: Benchmark.Configuration(
            metrics: defaultMetrics,
            scalingFactor: .kilo
        )
    ) { (benchmark) async throws -> Void in
        let emptyReader = ConfigReader(provider: InMemoryProvider(values: ["foo": 24]))
        for _ in benchmark.scaledIterations {
            blackHole(try await emptyReader.fetchInt(forKey: "foo"))
        }
    }

    Benchmark(
        "EnvironmentVariablesProvider_notFound_string",
        configuration: Benchmark.Configuration(
            metrics: defaultMetrics,
            scalingFactor: .kilo
        )
    ) { (benchmark) throws -> Void in
        let provider = EnvironmentVariablesProvider(environmentVariables: [:])
        let key: AbsoluteConfigKey = "foo"
        for _ in benchmark.scaledIterations {
            blackHole(try provider.value(forKey: key, type: .string))
        }
    }

    Benchmark(
        "EnvironmentVariablesProvider_found_string",
        configuration: Benchmark.Configuration(
            metrics: defaultMetrics,
            scalingFactor: .kilo
        )
    ) { (benchmark) throws -> Void in
        let provider = EnvironmentVariablesProvider(environmentVariables: ["foo": "bar"])
        let key: AbsoluteConfigKey = "foo"
        for _ in benchmark.scaledIterations {
            blackHole(try provider.value(forKey: key, type: .string))
        }
    }
}
