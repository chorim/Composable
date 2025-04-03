//
//  Conditional.swift
//  Composable
//
//  Created by Insu Byeon on 4/3/25.
//
import Foundation

public enum _Conditional<First: Reducer, Second: Reducer>: Reducer where First.State == Second.State, First.Action == Second.Action {
  
    case first(First)
    case second(Second)

    @inlinable
    public func reduce(in state: First.State, action: First.Action) async -> First.State {
        switch self {
        case let .first(first):
            return await first.reduce(in: state, action: action)
            
        case let .second(second):
            return await second.reduce(in: state, action: action)
        }
    }
}
