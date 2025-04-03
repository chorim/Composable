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
    associatedtype Body
    
    /// `reduce(in:action:)` 를 수행하기 전에 액션을 변이하는 함수입니다.
    ///
    /// 액션을 재정의하거나 여러가지 Action을 묶음으로 만들어서 전달할 수도 있습니다.
    ///
    /// - Note: 원본 액션에는 영향을 주지 않습니다.
    ///
    /// - Parameter action: `store(send:) 로 전달된 action
    /// - Returns: 변이된 Action을 반환합니다.
    func mutate(action: Action) async -> EmbedAction<Action>
    
    
    /// 입력된 Action 값을 통해 새로운 상태를 반환합니다.
    ///
    /// - Parameters:
    ///   - state: 현재 상태 값
    ///   - action: `store(send:) 로 전달된 action
    /// - Returns: 새로운 상태 값
    func reduce(in state: State, action: Action) async -> State
    
    /// 내부적으로 `reduce(in:action:)` 함수를 대신 호출합니다.
    ///
    /// `ReducerBuilder` 객체를 사용하여 여러개의 `Reducer`를 정의할 수 있습니다.
    @ReducerBuilder<State, Action>
    var body: Body { get }
}

extension Reducer {
    public func mutate(action: Action) async -> EmbedAction<Action> { .none }
}

public extension Reducer where Body == Never {
    @_transparent
    var body: Body {
        fatalError(
            """
            '\(Self.self)' has no body. …

            Do not access a reducer's 'body' property directly, as it may not exist. To run a reducer, \
            call 'Reducer.reduce(into:action:)', instead.
            """
        )
    }
}

public extension Reducer where Body: Reducer, Body.State == State, Body.Action == Action {
    @inlinable
    func reduce(in state: Body.State, action: Body.Action) async -> Body.State {
        return await body.reduce(in: state, action: action)
    }
}
