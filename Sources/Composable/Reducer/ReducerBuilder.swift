//
//  ReducerBuilder.swift
//  Composable
//
//  Created by Insu Byeon on 4/3/25.
//

import Foundation

@resultBuilder
public enum ReducerBuilder<State: ViewState, Action: Sendable> {
    @inlinable
    public static func buildArray<R: Reducer>(
        _ components: [R]
    ) -> _SequenceMany<R> where R.State == State, R.Action == Action {
        _SequenceMany(reducers: components)
    }
    
    @inlinable
    public static func buildBlock() -> EmptyReducer<State, Action> {
        EmptyReducer()
    }
    
    @inlinable
    public static func buildBlock<R: Reducer>(
        _ components: R
    ) -> R where R.State == State, R.Action == Action {
        components
    }
    
    @inlinable
    public static func buildEither<R0: Reducer, R1: Reducer>(
        first component: R0
    ) -> _Conditional<R0, R1> where R0.State == State, R0.Action == Action {
        .first(component)
    }
    
    @inlinable
    public static func buildEither<R0: Reducer, R1: Reducer>(
        second component: R1
    ) -> _Conditional<R0, R1> where R0.State == State, R0.Action == Action {
        .second(component)
    }
    
    @inlinable
    public static func buildExpression<R: Reducer>(
        _ expression: R
    ) -> R where R.State == State, R.Action == Action {
        expression
    }
    
    @inlinable
    public static func buildFinalResult<R: Reducer>(
        _ component: R
    ) -> R where R.State == State, R.Action == Action {
        component
    }
    
    @inlinable
    public static func buildOptional<R: Reducer>(
        _ component: R?
    ) -> R? where R.State == State, R.Action == Action {
        component
    }
    
    @inlinable
    public static func buildPartialBlock<R: Reducer>(
        first: R
    ) -> R where R.State == State, R.Action == Action {
        first
    }
    
    @inlinable
    public static func buildPartialBlock<R0: Reducer, R1: Reducer>(
        accumulated: R0,
        next: R1
    ) -> _Sequence<R0, R1> where R0.State == State, R0.Action == Action {
        _Sequence(accumulated, next)
    }
}
