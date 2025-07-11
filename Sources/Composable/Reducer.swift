//
//  Reducer.swift
//  Composable
//
//  Created by chorim.i on 3/27/25.
//

import Foundation
import CasePaths

public protocol Reducer<State, Action>: Sendable {
    associatedtype State: ViewState
    associatedtype Action: Sendable
    associatedtype Mutation: Sendable
    
    /// It takes in actions from actors that can be executed
    /// asynchronously and emits mutations that affect the UI.
    ///
    /// - Parameter action: Action from actor
    /// - Returns: Collections of variations that can affect the UI
    func mutate(isolation: isolated (any Actor)?, action: Action, emitter: MutationEmitter<Mutation>) async
    
    
    /// Mutate the state value with a new mutation that affects UI changes.
    /// Asynchronous operations should only happen in the `mutate(action:)` function.
    ///
    /// - Parameters:
    ///   - state: Current state value
    ///   - mutation: mutation passed to `store(send:)
    /// - Returns: New status value
    @MainActor func reduce(in state: State, mutation: Mutation) -> State
}

public extension Reducer {
    func pullback<GlobalState, GlobalAction, GlobalMutation>(
        state toLocalState: _SendableWritableKeyPath<GlobalState, State>,
        action fromGlobalAction: AnyCasePath<GlobalAction, Action>,
        mutation toGlobalMutation: @Sendable @escaping (Mutation) -> GlobalMutation,
        fromGlobalMutation: AnyCasePath<GlobalMutation, Mutation>
    ) -> PullbackReducer<Self, GlobalState, GlobalAction, GlobalMutation> {
        return PullbackReducer(
            base: self,
            toLocalState: toLocalState,
            fromGlobalAction: fromGlobalAction,
            toGlobalMutation: toGlobalMutation,
            fromGlobalMutation: fromGlobalMutation
        )
    }
    
    func pullback<GlobalState, GlobalAction, GlobalMutation>(
        state toLocalState: _SendableWritableKeyPath<GlobalState, State>,
        action fromGlobalAction: CaseKeyPath<GlobalAction, Action>,
        mutation toGlobalMutation: @Sendable @escaping (Mutation) -> GlobalMutation,
        fromGlobalMutation: CaseKeyPath<GlobalMutation, Mutation>
    ) -> PullbackReducer<Self, GlobalState, GlobalAction, GlobalMutation> {
        return pullback(state: toLocalState, action: AnyCasePath(fromGlobalAction), mutation: toGlobalMutation, fromGlobalMutation: AnyCasePath(fromGlobalMutation))
    }
    
    static func combine(_ reducers: [AnyReducer<State, Action, Mutation>]) -> CombinedReducer<State, Action, Mutation> {
        CombinedReducer(reducers)
    }
}
