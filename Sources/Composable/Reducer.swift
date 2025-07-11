//
//  Reducer.swift
//  Composable
//
//  Created by chorim.i on 3/27/25.
//

import Foundation

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
