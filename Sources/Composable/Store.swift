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
    private var label: String = "UnderlyingStore"
    
    @MainActor var isDebugging: Bool = false
    
    @MainActor
    public init(initialState: R.State, reducer: R) {
        self.state = initialState
        self.reducer = reducer
        
        (stream, continuation) = AsyncStream<R.State>.makeStream()
        (mutationStream, mutationContinuation) = AsyncStream<R.Mutation>.makeStream()
        
        continuation.yield(state)
        
        label = String(describing: type(of: self))
        
        Task { await processMutations() }
    }
    
    private func processMutations() async {
        for await mutation in mutationStream {
            await MainActor.run {
                let newState = reducer.reduce(in: state, mutation: mutation)
                if isDebugging, let differences = diff(state, newState, label: label) {
                    // TODO: Need to inject DebugLogInterface externally and have it call its methods
                    print(differences)
                }
                self.state = newState
            }
        }
    }
    
    public func send(isolation: isolated (any Actor)? = #isolation, action: R.Action) async {
        let emitter = MutationEmitter<R.Mutation>(continuation: .init(mutationContinuation))
        await reducer.mutate(isolation: isolation, action: action, emitter: emitter)
    }
    
    @MainActor
    public func mutate(_ mutation: R.Mutation) {
        state = reducer.reduce(in: state, mutation: mutation)
    }
    
    @MainActor
    public func cancelTask(id: AnyHashable) {
        taskRegistry.cancel(id: id)
    }

    @MainActor
    public func cancelAllTasks() {
        taskRegistry.cancelAll()
    }
    
    @MainActor
    public func setDebugging(_ isDebugging: Bool) {
        self.isDebugging = isDebugging
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
                guard let self else { return }
                let newState = reducer.reduce(in: self.state, mutation: mutation(value))
                self.state = newState
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
                    Task { @MainActor in
                        await self?.send(action: action(newValue))
                    }
                }
            }
        )
    }
}
