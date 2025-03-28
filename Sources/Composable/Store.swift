//
//  Store.swift
//  Composable
//
//  Created by chorim.i on 3/27/25.
//

import Foundation
import Combine

public typealias ComposableStore<R: Reducer> = Store<R, R.State, R.Action>

public actor Store<R: Reducer, S: ViewState, A: Sendable>: ObservableObject, Identifiable {
    public let id: UUID = UUID()
    
    @MainActor
    private(set) var state: S {
        willSet {
            objectWillChange.send()
        }
        didSet {
            continuation.yield(state)
        }
    }
    
    private let reducer: R
    private let continuation: AsyncStream<S>.Continuation
    
    let stream: AsyncStream<S>
    
    init(state: S, reducer: R) where R.State == S, R.Action == A {
        self.state = state
        self.reducer = reducer
        
        (stream, continuation) = AsyncStream<S>.makeStream()
        
        continuation.yield(state)
    }
    
    func send(action: sending A) async where R: Sendable, R.State == S, R.Action == A {
        var newState = await state
        
        newState = await reducer.reduce(in: newState, action: action)
        
        // UI update should be called on the main thread;
        await MainActor.run { state = newState }
    }
}

extension Store: Hashable {
    nonisolated public func hash(into hasher: inout Hasher) {
        // Needs more to hashing item..
        hasher.combine(id)
    }
    
    public static func == (lhs: Store<R, S, A>, rhs: Store<R, S, A>) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: Store utils for send
public extension Store {
    func send(_ factory: () async -> A) async where R.State == S, R.Action == A {
        await send(action: await factory())
    }
    
    func send(_ factory: () async throws -> A) async where R.State == S, R.Action == A {
        if let action = try? await factory() {
            await send(action: action)
        }
    }
    
    func send<Seq: AsyncSequence>(
        sequence: Seq
    ) async throws where Seq.Element == A, R.State == S, R.Action == A {
        for try await action in sequence {
            await send(action: action)
        }
    }
    
    func merge(_ sequence: Array<A>) async where R.State == S, R.Action == A {
        for action in sequence {
            await send(action: action)
        }
    }
    
    func merge(_ factory: () async -> [A]) async where R.State == S, R.Action == A {
        for action in await factory() {
            await send(action: action)
        }
    }
}
