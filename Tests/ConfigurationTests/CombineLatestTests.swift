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
//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Async Algorithms open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

import XCTest
@testable import Configuration
import AsyncAlgorithms
import Synchronization

@available(Configuration 1.0, *)
final class TestCombineLatestMany: XCTestCase {
  func test_combineLatest() async throws {
    let a = [1, 2, 3].async
    let b = [4, 5, 6].async
    let c = [7, 8, 9].async
    let sequence = combineLatestMany([a, b, c])
    let actual = await Array(sequence)
    XCTAssertGreaterThanOrEqual(actual.count, 3)
  }

  func test_ordering1() async {
    var a = GatedSequence([1, 2, 3])
    var b = GatedSequence([4, 5, 6])
    var c = GatedSequence([7, 8, 9])
    let finished = expectation(description: "finished")
    let sequence = combineLatestMany([a, b, c])
    let validator = Validator<[Int]>()
    validator.test(sequence) { iterator in
      let pastEnd = await iterator.next(isolation: nil)
      XCTAssertNil(pastEnd)
      finished.fulfill()
    }
    var value = await validator.validate()
    XCTAssertEqual(value, [])
    a.advance()
    value = validator.current
    XCTAssertEqual(value, [])
    b.advance()
    value = validator.current
    XCTAssertEqual(value, [])
    c.advance()

    value = await validator.validate()
    XCTAssertEqual(value, [[1, 4, 7]])
    a.advance()

    value = await validator.validate()
    XCTAssertEqual(value, [[1, 4, 7], [2, 4, 7]])
    b.advance()

    value = await validator.validate()
    XCTAssertEqual(value, [[1, 4, 7], [2, 4, 7], [2, 5, 7]])
    c.advance()

    value = await validator.validate()
    XCTAssertEqual(value, [[1, 4, 7], [2, 4, 7], [2, 5, 7], [2, 5, 8]])
    a.advance()

    value = await validator.validate()
    XCTAssertEqual(value, [[1, 4, 7], [2, 4, 7], [2, 5, 7], [2, 5, 8], [3, 5, 8]])
    b.advance()

    value = await validator.validate()
    XCTAssertEqual(value, [[1, 4, 7], [2, 4, 7], [2, 5, 7], [2, 5, 8], [3, 5, 8], [3, 6, 8]])
    c.advance()

    value = await validator.validate()
    XCTAssertEqual(
      value,
      [[1, 4, 7], [2, 4, 7], [2, 5, 7], [2, 5, 8], [3, 5, 8], [3, 6, 8], [3, 6, 9]]
    )

    await fulfillment(of: [finished], timeout: 1.0)
    value = validator.current
    XCTAssertEqual(
      value,
      [[1, 4, 7], [2, 4, 7], [2, 5, 7], [2, 5, 8], [3, 5, 8], [3, 6, 8], [3, 6, 9]]
    )
  }
}

@available(Configuration 1.0, *)
public final class Validator<Element: Sendable>: Sendable {
  private enum Ready {
    case idle
    case ready
    case pending(UnsafeContinuation<Void, Never>)
  }

  private struct State: Sendable {
    var collected = [Element]()
    var failure: (any Error)?
    var ready: Ready = .idle
  }

  private struct Envelope<Contents>: @unchecked Sendable {
    var contents: Contents
  }

  private let state = Mutex(State())

  private func ready(_ apply: (inout State) -> Void) {
    state.withLock { state -> UnsafeContinuation<Void, Never>? in
      apply(&state)
      switch state.ready {
      case .idle:
        state.ready = .ready
        return nil
      case .pending(let continuation):
        state.ready = .idle
        return continuation
      case .ready:
        return nil
      }
    }?.resume()
  }

  internal func step() async {
    await withUnsafeContinuation { (continuation: UnsafeContinuation<Void, Never>) in
      state.withLock { state -> UnsafeContinuation<Void, Never>? in
        switch state.ready {
        case .ready:
          state.ready = .idle
          return continuation
        case .idle:
          state.ready = .pending(continuation)
          return nil
        case .pending:
          fatalError()
        }
      }?.resume()
    }
  }

  let onEvent: (@Sendable (Result<Element?, any Error>) async -> Void)?

  init(onEvent: @Sendable @escaping (Result<Element?, any Error>) async -> Void) {

    self.onEvent = onEvent
  }

  public init() {
    self.onEvent = nil
  }

  public func test<S: AsyncSequence & SendableMetatype>(
    _ sequence: S,
    onFinish: @Sendable @escaping (inout S.AsyncIterator) async -> Void
  ) where S.Element == Element {
    let envelope = Envelope(contents: sequence)
    Task {
      var iterator = envelope.contents.makeAsyncIterator()
      ready { _ in }
      do {
        while let item = try await iterator.next() {
          await onEvent?(.success(item))
          ready { state in
            state.collected.append(item)
          }
        }
        await onEvent?(.success(nil))
      } catch {
        await onEvent?(.failure(error))
        ready { state in
          state.failure = error
        }
      }
      ready { _ in }
      await onFinish(&iterator)
    }
  }

  public func validate() async -> [Element] {
    await step()
    return current
  }

  public var current: [Element] {
    return state.withLock { state in
      return state.collected
    }
  }

  public var failure: (any Error)? {
    return state.withLock { state in
      return state.failure
    }
  }
}
