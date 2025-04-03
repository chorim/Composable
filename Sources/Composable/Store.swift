//
//  Store.swift
//  Composable
//
//  Created by Insu Byeon on 3/27/25.
//

import Foundation
import Combine

public typealias ComposableStore<R: Reducer> = Store<R, R.State, R.Action>

public actor Store<R: Reducer, S: ViewState, A: Sendable>: ObservableObject, Identifiable {
    public let id: UUID = UUID()
    
    @MainActor
    public private(set) var state: S {
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
    
    public init(state: S, reducer: R) where R.State == S, R.Action == A {
        self.state = state
        self.reducer = reducer
        
        (stream, continuation) = AsyncStream<S>.makeStream()
        
        continuation.yield(state)
    }
    
    public func send(action: sending A) async where R: Sendable, R.State == S, R.Action == A {
        var newState = await state
        
        switch await reducer.mutate(action: action) {
        case .concat(let multipleActions):
            // 여러개의 액션을 순차적으로 수행한다.
            for action in multipleActions {
                newState = await reducer.reduce(in: newState, action: action)
                // 실행한 하나의 액션마다 새로운 상태를 방출한다.
                await MainActor.run { state = newState }
            }
        case .none:
            newState = await reducer.reduce(in: newState, action: action)
            // UI update should be called on the main thread;
            await MainActor.run { state = newState }
        }
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
