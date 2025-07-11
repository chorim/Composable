//
//  CombinedReducer.swift
//  Composable
//
//  Created by chorim.i on 7/11/25.
//

import SwiftUI

public struct CombinedReducer<State: ViewState, Action: Sendable, Mutation: Sendable>: Reducer {
    private let reducers: [AnyReducer<State, Action, Mutation>]
    
    public init(_ reducers: [AnyReducer<State, Action, Mutation>]) {
        self.reducers = reducers
    }

    public func mutate(isolation: isolated(any Actor)?, action: Action, emitter: MutationEmitter<Mutation>) async {
        for reducer in reducers {
            await reducer.mutate(isolation: isolation, action: action, emitter: emitter)
        }
    }

    @MainActor
    public func reduce(in state: State, mutation: Mutation) -> State {
        var state = state
        for reducer in reducers {
            state = reducer.reduce(in: state, mutation: mutation)
        }
        return state
    }
}
