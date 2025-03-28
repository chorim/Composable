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
    
    func reduce(in state: State, action: Action) async -> State
}
