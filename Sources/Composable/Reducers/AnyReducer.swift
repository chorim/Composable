//
//  AnyReducer.swift
//  Composable
//
//  Created by chorim.i on 7/11/25.
//
import SwiftUI

public struct AnyReducer<State: ViewState, Action: Sendable, Mutation: Sendable>: Reducer {
    private let _mutate: @Sendable (isolated(any Actor)?, Action, MutationEmitter<Mutation>) async -> Void
    private let _reduce: @MainActor @Sendable (State, Mutation) -> State

    public init<R: Reducer>(_ base: R) where R.State == State, R.Action == Action, R.Mutation == Mutation {
        self._mutate = { actor, action, emitter in
            await base.mutate(isolation: actor, action: action, emitter: emitter)
        }
        self._reduce = { state, mutation in
            base.reduce(in: state, mutation: mutation)
        }
    }

    public func mutate(isolation: isolated(any Actor)?, action: Action, emitter: MutationEmitter<Mutation>) async {
        await _mutate(isolation, action, emitter)
    }

    @MainActor
    public func reduce(in state: State, mutation: Mutation) -> State {
        _reduce(state, mutation)
    }
}
