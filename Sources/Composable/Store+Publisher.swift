//
//  Store+Publisher.swift
//  Composable
//
//  Created by chorim.i on 3/27/25.
//

#if canImport(Darwin)
import Foundation
import Combine
import Darwin

/// https://github.com/vmanot/Merge/blob/master/Sources/Merge/Intermodular/Helpers/Combine/AsyncSequencePublisher.swift
public struct AsyncSequencePublisher<Base: AsyncSequence & Sendable, Failure: Error>: Combine.Publisher {
    public typealias Output = Base.Element
    
    private var sequence: Base
    
    public init(_ sequence: Base) {
        self.sequence = sequence
    }
    
    public func receive<_S: Subscriber<Output, Failure>>(
        subscriber: _S
    )  {
        subscriber.receive(
            subscription: Subscription(subscriber: subscriber, sequence: sequence)
        )
    }
    
    final class Subscription<
        Subscriber: Combine.Subscriber
    >: Combine.Subscription, @unchecked Sendable where Subscriber.Input == Output, Subscriber.Failure == Failure {
        
        private var sequence: Base
        private var subscriber: Subscriber
        private var isCancelled = false
        
        private var lock = OSUnfairLock()
        private var demand: Subscribers.Demand = .none
        private var task: Task<Void, Error>?
        
        init(subscriber: Subscriber, sequence: Base) {
            self.sequence = sequence
            self.subscriber = subscriber
        }
        
        func request(_ __demand: Subscribers.Demand) {
            precondition(__demand > 0)
            
            lock.withCriticalScope {
                demand = __demand
            }
            
            guard task == nil else {
                return
            }
            
            lock.lockOrBlock()
            
            defer {
                lock.unlock()
            }
            
            task = Task {
                var iterator = lock.withCriticalScope {
                    sequence.makeAsyncIterator()
                }
                
                while lock.withCriticalScope(perform: { !isCancelled && demand > 0 }) {
                    let element: Base.Element?
                    
                    do {
                        element = try await iterator.next()
                    } catch is CancellationError {
                        lock.withCriticalScope {
                            subscriber
                        }
                        .receive(completion: .finished)
                        
                        return
                    } catch let error as Failure {
                        lock.withCriticalScope {
                            subscriber
                        }
                        .receive(completion: .failure(error))
                        
                        throw CancellationError()
                    } catch {
                        assertionFailure("Expected \(Failure.self) but got \(type(of: error))")
                        
                        throw CancellationError()
                    }
                    
                    guard let element else {
                        lock.withCriticalScope {
                            subscriber
                        }
                        .receive(completion: .finished)
                        
                        throw CancellationError()
                    }
                    
                    try Task.checkCancellation()
                    
                    lock.withCriticalScope {
                        demand -= 1
                    }
                    
                    let newDemand = lock.withCriticalScope {
                        subscriber
                    }.receive(element)
                                        
                    lock.withCriticalScope {
                        demand += newDemand
                    }
                    
                    await Task.yield()
                }
                
                task = nil
            }
        }
        
        func cancel() {
            lock.withCriticalScope {
                task?.cancel()
                isCancelled = true
            }
        }
    }
}

/// An `os_unfair_lock` wrapper.
final class OSUnfairLock: @unchecked Sendable {
    @usableFromInline
    let base: os_unfair_lock_t
    
    init() {
        let base = os_unfair_lock_t.allocate(capacity: 1)
        
        base.initialize(repeating: os_unfair_lock_s(), count: 1)

        self.base = base
    }

    @inlinable
    func lockOrBlock() {
        os_unfair_lock_lock(base)
    }
    
    @inlinable
    func lockOrFail() throws {
        let didLocked = os_unfair_lock_trylock(base)
        
        if !didLocked {
            throw UnfairLockError.failedToAcquireLock
        }
    }

    @inlinable
    func unlock() {
        os_unfair_lock_unlock(base)
    }
    
    deinit {
        base.deinitialize(count: 1)
        base.deallocate()
    }
}

extension OSUnfairLock {
    @discardableResult
    @inlinable
    @inline(__always)
    func withCriticalScope<Result>(
        perform action: () -> Result
    ) -> Result {
        defer {
            unlock()
        }
        
        lockOrBlock()
        
        return action()
    }
}

// MARK: - Error Handling

extension OSUnfairLock {
    @usableFromInline
    enum UnfairLockError: Error {
        case failedToAcquireLock
    }
}

extension Store {
    private typealias PublisherType = AsyncSequencePublisher<AsyncStream<R.State>, Never>
    
    @MainActor private var publisher: PublisherType {
        return AsyncSequencePublisher<AsyncStream<R.State>, Never>(stream)
    }
    
    @MainActor private var receiveOnMainThread: Publishers.ReceiveOn<PublisherType, DispatchQueue> {
        return publisher.receive(on: DispatchQueue.main)
    }
    
    @MainActor public func asPublisher() -> AnyPublisher<R.State, Never> {
        return receiveOnMainThread.eraseToAnyPublisher()
    }
    
    @MainActor public func asPublisher<T>(_ keyPath: KeyPath<R.State, T>) -> AnyPublisher<T, Never> {
        return receiveOnMainThread.map(keyPath).eraseToAnyPublisher()
    }
}
#endif
