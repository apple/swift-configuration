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
// Copyright (c) 2022 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

import Synchronization

@available(Configuration 1.0, *)
public struct GatedSequence<Element> {
  public typealias Failure = Never
  let elements: [Element]
  let gates: [Gate]
  var index = 0

  public mutating func advance() {
    defer { index += 1 }
    guard index < gates.count else {
      return
    }
    gates[index].open()
  }

  public init(_ elements: [Element]) {
    self.elements = elements
    self.gates = elements.map { _ in Gate() }
  }
}

@available(*, unavailable)
extension GatedSequence.Iterator: Sendable {}

@available(Configuration 1.0, *)
extension GatedSequence: AsyncSequence {
  public struct Iterator: AsyncIteratorProtocol {
    var gatedElements: [(Element, Gate)]

    init(elements: [Element], gates: [Gate]) {
      gatedElements = Array(zip(elements, gates))
    }

    public mutating func next() async -> Element? {
      guard gatedElements.count > 0 else {
        return nil
      }
      let (element, gate) = gatedElements.removeFirst()
      await gate.enter()
      return element
    }

    public mutating func next(isolation actor: isolated (any Actor)?) async throws(Never) -> Element? {
      guard gatedElements.count > 0 else {
        return nil
      }
      let (element, gate) = gatedElements.removeFirst()
      await gate.enter()
      return element
    }
  }

  public func makeAsyncIterator() -> Iterator {
    Iterator(elements: elements, gates: gates)
  }
}

@available(Configuration 1.0, *)
extension GatedSequence: Sendable where Element: Sendable {}

@available(Configuration 1.0, *)
public final class Gate: Sendable {
  enum State {
    case closed
    case open
    case pending(UnsafeContinuation<Void, Never>)
  }

  let state = Mutex(State.closed)

  public func `open`() {
    state.withLock { state -> UnsafeContinuation<Void, Never>? in
      switch state {
      case .closed:
        state = .open
        return nil
      case .open:
        return nil
      case .pending(let continuation):
        state = .closed
        return continuation
      }
    }?.resume()
  }

  public func enter() async {
    var other: UnsafeContinuation<Void, Never>?
    await withUnsafeContinuation { (continuation: UnsafeContinuation<Void, Never>) in
      state.withLock { state -> UnsafeContinuation<Void, Never>? in
        switch state {
        case .closed:
          state = .pending(continuation)
          return nil
        case .open:
          state = .closed
          return continuation
        case .pending(let existing):
          other = existing
          state = .pending(continuation)
          return nil
        }
      }?.resume()
    }
    other?.resume()
  }
}
