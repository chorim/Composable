//
//  CombineReducer.swift
//  Composable
//
//  Created by Insu Byeon on 4/3/25.
//
import Foundation

public struct CombineReducer<State: ViewState, Action: Sendable>: Reducer {
    private var _reducers = Reducers(reducers: [])

    public init(reducers: some Collection<any Reducer<State, Action>>) {
        var array = Array<any Reducer<State, Action>>()
        array.append(contentsOf: reducers)
        _reducers = .init(reducers: array)
    }
    
    public init(reducers: any Reducer<State, Action>...) {
        var array = Array<any Reducer<State, Action>>()
        array.append(contentsOf: reducers)
        _reducers = .init(reducers: array)
    }
    
    public func reduce(in state: State, action: Action) async -> State {
        await _reducers.reducers.asyncReduce(state) {
            await $1.reduce(in: $0, action: action)
        }
    }
    
    actor Reducers {
        let reducers: [any Reducer<State, Action>]
        
        init(reducers: [any Reducer<State, Action>]) {
            self.reducers = reducers
        }
    }
}

extension Sequence {
    /// Returns the result of combining the elements of the asynchronous sequence using the given closure, given a mutable initial value.
    ///
    /// - Parameters:
    ///   - initialResult: The value to use as the initial accumulating value. The `nextPartialResult` closure receives `initialResult` the first time the closure executes.
    ///   - nextPartialResult: A closure that combines an accumulating value and an element of the asynchronous sequence into a new accumulating value, for use in the next call of the `nextPartialResult closure or returned to the caller.
    /// - Returns: The final accumulated value. If the sequence has no elements, the result is `initialResult`.
    func asyncReduce<Result>(
        _ initialResult: Result,
        _ nextPartialResult: ((Result, Element) async throws -> Result)
    ) async rethrows -> Result {
        var result = initialResult
        for element in self {
            result = try await nextPartialResult(result, element)
        }
        return result
    }
}
