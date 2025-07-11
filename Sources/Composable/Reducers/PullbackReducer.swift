//
//  PullbackReducer.swift
//  Composable
//
//  Created by chorim.i on 7/11/25.
//

import SwiftUI
import CasePaths

#if compiler(>=6)
  public typealias _SendableKeyPath<Root, Value> = any KeyPath<Root, Value> & Sendable
  public typealias _SendableWritableKeyPath<Root, Value> = any WritableKeyPath<Root, Value>
    & Sendable
#else
  public typealias _SendableKeyPath<Root, Value> = KeyPath<Root, Value>
  public typealias _SendableWritableKeyPath<Root, Value> = WritableKeyPath<Root, Value>
#endif

public struct PullbackReducer<
    Base: Reducer,
    GlobalState: ViewState,
    GlobalAction: Sendable,
    GlobalMutation: Sendable
>: Reducer
where
    Base.State: Sendable & ViewState,
    Base.Action: Sendable,
    Base.Mutation: Sendable
{
    public typealias LocalState = Base.State
    public typealias LocalAction = Base.Action
    public typealias LocalMutation = Base.Mutation

    public typealias State = GlobalState
    public typealias Action = GlobalAction
    public typealias Mutation = GlobalMutation
    
    let base: Base
    let toLocalState: _SendableWritableKeyPath<GlobalState, LocalState>
    let fromGlobalAction: AnyCasePath<GlobalAction, LocalAction>
    let toGlobalMutation: @Sendable (LocalMutation) -> GlobalMutation
    let fromGlobalMutation: AnyCasePath<GlobalMutation, LocalMutation>

    public init(
        base: Base,
        toLocalState: _SendableWritableKeyPath<GlobalState, Base.State>,
        fromGlobalAction: AnyCasePath<GlobalAction, Base.Action>,
        toGlobalMutation: @Sendable @escaping (Base.Mutation) -> GlobalMutation,
        fromGlobalMutation: AnyCasePath<GlobalMutation, Base.Mutation>
    ) {
        self.base = base
        self.toLocalState = toLocalState
        self.fromGlobalAction = fromGlobalAction
        self.toGlobalMutation = toGlobalMutation
        self.fromGlobalMutation = fromGlobalMutation
    }

    public func mutate(isolation: isolated(any Actor)?, action: GlobalAction, emitter: MutationEmitter<GlobalMutation>) async {
        guard let localAction = fromGlobalAction.extract(from: action) else { return }
        
        let (localStream, localContinuation) = AsyncStream<Base.Mutation>.makeStream()
        let localEmitter = MutationEmitter<Base.Mutation>(continuation: .init(localContinuation))
        
        let forwardingTask = Task {
            for await localMutation in localStream {
                await emitter.emit(toGlobalMutation(localMutation))
            }
        }
        
        await base.mutate(isolation: isolation, action: localAction, emitter: localEmitter)

        localContinuation.finish()
        
        await forwardingTask.value
    }

    @MainActor
    public func reduce(in state: GlobalState, mutation: GlobalMutation) -> GlobalState {
        var state = state
        if let localMutation = fromGlobalMutation.extract(from: mutation) {
            let localState = state[keyPath: toLocalState]
            let newLocalState = base.reduce(in: localState, mutation: localMutation)
            state[keyPath: toLocalState] = newLocalState
        }
        return state
    }
}

