//
//  Reduce.swift
//  Composable
//
//  Created by Insu Byeon on 4/3/25.
//
import Foundation

public struct Reduce<State: ViewState, Action: Sendable>: Reducer {
    let _reduce: @Sendable (State, Action) async -> State
    
    public init(_ reduce: @escaping @Sendable (_ state: State, _ action: Action) async -> State) {
        self.init(internal: reduce)
    }
    
    public init<R: Reducer>(_ reducer: R) where R.State == State, R.Action == Action {
        self.init(internal: reducer.reduce)
    }
    
    private init(internal reduce: @escaping @Sendable (State, Action) async -> State) {
        _reduce = reduce
    }
    
    public func reduce(in state: State, action: Action) async -> State {
        return await _reduce(state, action)
    }
}
