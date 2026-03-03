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

import Synchronization

// Vendored copy of https://github.com/apple/swift-async-algorithms/pull/360

@available(Configuration 1.0, *)
final class CombineLatestManyStorage<Element: Sendable, Failure: Error>: Sendable {
    typealias StateMachine = CombineLatestManyStateMachine<Element, Failure>

    private let stateMachine: Mutex<StateMachine>

    init(_ bases: [any StateMachine.Base]) {
        self.stateMachine = .init(.init(bases: bases))
    }

    func iteratorDeinitialized() {
        let action = self.stateMachine.withLock { $0.iteratorDeinitialized() }

        switch action {
        case .cancelTaskAndUpstreamContinuations(
            let task,
            let upstreamContinuation
        ):
            task.cancel()
            for item in upstreamContinuation {
                item.resume()
            }

        case .none:
            break
        }
    }

    func next() async throws(Failure) -> [Element]? {
        let result = await withTaskCancellationHandler {
            await withUnsafeContinuation { continuation in
                let action: StateMachine.NextAction? = self.stateMachine.withLock { stateMachine in
                    let action = stateMachine.next(for: continuation)
                    switch action {
                    case .startTask(let bases):
                        // first iteration, we start one child task per base to iterate over them
                        self.startTask(
                            stateMachine: &stateMachine,
                            bases: bases,
                            downstreamContinuation: continuation
                        )
                        return nil

                    case .resumeContinuation:
                        return action

                    case .resumeUpstreamContinuations:
                        return action

                    case .resumeDownstreamContinuationWithNil:
                        return action
                    }
                }

                switch action {
                case .startTask:
                    // We are handling the startTask in the lock already because we want to avoid
                    // other inputs interleaving while starting the task
                    fatalError("Internal inconsistency")

                case .resumeContinuation(let downstreamContinuation, let result):
                    downstreamContinuation.resume(returning: result)

                case .resumeUpstreamContinuations(let upstreamContinuations):
                    // bases can be iterated over for 1 iteration so their next value can be retrieved
                    for item in upstreamContinuations {
                        item.resume()
                    }

                case .resumeDownstreamContinuationWithNil(let continuation):
                    // the async sequence is already finished, immediately resuming
                    continuation.resume(returning: .success(nil))

                case .none:
                    break
                }
            }
        } onCancel: {
            let action = self.stateMachine.withLock { stateMachine in
                stateMachine.cancelled()
            }

            switch action {
            case .resumeDownstreamContinuationWithNilAndCancelTaskAndUpstreamContinuations(
                let downstreamContinuation,
                let task,
                let upstreamContinuations
            ):
                task.cancel()
                for item in upstreamContinuations {
                    item.resume()
                }

                downstreamContinuation.resume(returning: .success(nil))

            case .cancelTaskAndUpstreamContinuations(let task, let upstreamContinuations):
                task.cancel()
                for item in upstreamContinuations {
                    item.resume()
                }

            case .none:
                break
            }
        }
        return try result.get()
    }

    private func startTask(
        stateMachine: inout StateMachine,
        bases: [any (AsyncSequence<Element, Failure> & Sendable)],
        downstreamContinuation: StateMachine.DownstreamContinuation
    ) {
        // This creates a new `Task` that is iterating the upstream
        // sequences. We must store it to cancel it at the right times.
        let task = Task {
            await withTaskGroup(of: Result<Void, Failure>.self) { group in
                // For each upstream sequence we are adding a child task that
                // is consuming the upstream sequence
                for (baseIndex, base) in bases.enumerated() {
                    group.addTask {
                        var baseIterator = base.makeAsyncIterator()

                        loop: while true {
                            // We are creating a continuation before requesting the next
                            // element from upstream. This continuation is only resumed
                            // if the downstream consumer called `next` to signal his demand.
                            await withUnsafeContinuation { continuation in
                                let action = self.stateMachine.withLock { stateMachine in
                                    stateMachine.childTaskSuspended(baseIndex: baseIndex, continuation: continuation)
                                }

                                switch action {
                                case .resumeContinuation(let upstreamContinuation):
                                    upstreamContinuation.resume()

                                case .none:
                                    break
                                }
                            }

                            let element: Element?
                            do {
                                element = try await baseIterator.next(isolation: nil)
                            } catch {
                                return .failure(error as! Failure)  // Looks like a compiler bug
                            }

                            if let element = element {
                                let action = self.stateMachine.withLock { stateMachine in
                                    stateMachine.elementProduced(value: element, atBaseIndex: baseIndex)
                                }

                                switch action {
                                case .resumeContinuation(let downstreamContinuation, let result):
                                    downstreamContinuation.resume(returning: result)

                                case .none:
                                    break
                                }
                            } else {
                                let action = self.stateMachine.withLock { stateMachine in
                                    stateMachine.upstreamFinished(baseIndex: baseIndex)
                                }

                                switch action {
                                case .resumeContinuationWithNilAndCancelTaskAndUpstreamContinuations(
                                    let downstreamContinuation,
                                    let task,
                                    let upstreamContinuations
                                ):

                                    task.cancel()
                                    for item in upstreamContinuations {
                                        item.resume()
                                    }

                                    downstreamContinuation.resume(returning: .success(nil))
                                    break loop

                                case .cancelTaskAndUpstreamContinuations(let task, let upstreamContinuations):
                                    task.cancel()
                                    for item in upstreamContinuations {
                                        item.resume()
                                    }

                                    break loop

                                case .none:
                                    break loop
                                }
                            }
                        }
                        return .success(())
                    }
                }

                while !group.isEmpty {
                    let result = await group.next()

                    switch result {
                    case .success, .none:
                        break
                    case .failure(let error):
                        // One of the upstream sequences threw an error
                        let action = self.stateMachine.withLock { stateMachine in
                            stateMachine.upstreamThrew(error)
                        }

                        switch action {
                        case .cancelTaskAndUpstreamContinuations(let task, let upstreamContinuations):
                            task.cancel()
                            for item in upstreamContinuations {
                                item.resume()
                            }
                        case .resumeContinuationWithFailureAndCancelTaskAndUpstreamContinuations(
                            let downstreamContinuation,
                            let error,
                            let task,
                            let upstreamContinuations
                        ):
                            task.cancel()
                            for item in upstreamContinuations {
                                item.resume()
                            }
                            downstreamContinuation.resume(returning: .failure(error))
                        case .none:
                            break
                        }

                        group.cancelAll()
                    }
                }
            }
        }

        stateMachine.taskIsStarted(task: task, downstreamContinuation: downstreamContinuation)
    }
}
