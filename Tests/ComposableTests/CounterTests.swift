//
//  CounterTests.swift
//  Composable
//
//  Created by chorim.i on 3/27/25.
//

import Testing
@testable import Composable

fileprivate struct CounterReducer: Reducer {
    struct State: ViewState {
        var counter: Int = 0
    }
    
    enum Action: Sendable {
        case increase(Int)
        case decrease(Int)
    }
    
    func reduce(in state: State, action: Action) async -> State {
        var newState = state
        switch action {
        case let .increase(value):
            newState.counter += value
        case let .decrease(value):
            newState.counter -= value
        }
        return newState
    }
}

@Test func testIncreamentAndDecrement() async throws {
    let testStore = TestStore(
        state: CounterReducer.State(),
        reducer: CounterReducer()
    )
    
    await testStore.send(action: .increase(1)) {
        $0.counter = 1
    }
    
    await testStore.send(action: .decrease(1)) {
        $0.counter = 0
    }
    
    let isFailure = await testStore.isFailure
    let failureMessage = await testStore.failureMessage
    
    #expect(isFailure == false, Comment(rawValue: failureMessage))
}

