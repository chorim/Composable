//
//  Store.swift
//  Composable
//
//  Created by Insu Byeon on 3/27/25.
//

import Foundation
import Combine
import SwiftUI

public actor Store<R: Reducer>: ObservableObject, Identifiable
where R.State: Sendable, R.Action: Sendable {
    public let id: UUID = UUID()
    
    @MainActor
    public private(set) var state: R.State {
        willSet { objectWillChange.send() }
        didSet { continuation.yield(state) }
    }
    
    @MainActor
    public private(set) var taskRegistry = CancellableTaskRegistry<AnyHashable>()
    
    private let reducer: R
    private let continuation: AsyncStream<R.State>.Continuation
    let stream: AsyncStream<R.State>
    
    private let mutationContinuation: AsyncStream<R.Mutation>.Continuation
    private let mutationStream: AsyncStream<R.Mutation>
    
    @MainActor
    public init(initialState: R.State, reducer: R) {
        self.state = initialState
        self.reducer = reducer
        
        (stream, continuation) = AsyncStream<R.State>.makeStream()
        (mutationStream, mutationContinuation) = AsyncStream<R.Mutation>.makeStream()
        
        continuation.yield(state)
    }
    
    public func send(isolation: isolated (any Actor)? = #isolation, action: R.Action) async {
        let (mutationStream, mutationContinuation) = AsyncStream<R.Mutation>.makeStream()
        let emitter = MutationEmitter<R.Mutation>(continuation: .init(mutationContinuation))

        let reducerTask = Task {
            for await mutation in mutationStream {
                let newState = await reducer.reduce(in: await state, mutation: mutation)
                await MainActor.run { self.state = newState }
            }
        }

        await reducer.mutate(isolation: #isolation, action: action, emitter: emitter)

        mutationContinuation.finish()
        await reducerTask.value
    }
    
    @MainActor
    public func cancelTask(id: AnyHashable) {
        taskRegistry.cancel(id: id)
    }

    @MainActor
    public func cancelAllTasks() {
        taskRegistry.cancelAll()
    }
    
    // MARK: - Binding
    @MainActor
    public func binding<V>(
        get: @escaping (R.State?) -> V,
        mutation: @escaping (V) -> R.Mutation
    ) -> Binding<V> where V: Equatable {
        Binding { [weak self] in
            get(self?.state)
        } set: { [weak self] value in
            if get(self?.state) != value {
                Task {
                    guard let self else { return }
                    let newState = self.reducer.reduce(in: self.state, mutation: mutation(value))
                    await MainActor.run {
                        self.state = newState
                    }
                }
            }
        }
    }
    
    @MainActor
    public func binding<V>(
        get: @escaping (R.State?) -> V,
        send action: @escaping (V) -> Void
    ) -> Binding<V> where V: Equatable {
        Binding(
            get: { [weak self] in
                return get(self?.state)
            },
            set: { [weak self] newValue in
                if get(self?.state) != newValue {
                    action(newValue)
                }
            }
        )
    }
    
    @MainActor
    public func binding<V>(
        get: @escaping (R.State?) -> V,
        compactSend action: @escaping (V) -> R.Action
    ) -> Binding<V> where V: Equatable {
        Binding(
            get: { [weak self] in get(self?.state) },
            set: { [weak self] newValue in
                if get(self?.state) != newValue {
                    Task {
                        await self?.send(action: action(newValue))
                    }
                }
            }
        )
    }
}
