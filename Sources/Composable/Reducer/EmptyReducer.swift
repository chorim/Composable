//
//  EmptyReducer.swift
//  Composable
//
//  Created by Insu Byeon on 4/3/25.
//
import Foundation

public struct EmptyReducer<State: ViewState, Action: Sendable>: Reducer {
    public init() {}
    
    public func reduce(in state: State, action: Action) async -> State {
        return state
    }
}
