//
//  SequenceMany.swift
//  Composable
//
//  Created by Insu Byeon on 4/3/25.
//
import Foundation

public struct _SequenceMany<R: Reducer>: Reducer {
    @usableFromInline
    let reducers: [R]
    
    public init(reducers: [R]) {
        self.reducers = reducers
    }
    
    public func reduce(in state: R.State, action: R.Action) async -> R.State {
        return await CombineReducer(reducers: reducers)
            .reduce(in: state, action: action)
    }
}
