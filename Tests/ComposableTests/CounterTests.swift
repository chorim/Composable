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
        case increment(Int)
        case decrement(Int)
    }
    
    enum Mutation {
        case increase(Int)
        case decrease(Int)
    }
    
    func mutate(isolation: isolated (any Actor)?, action: Action, emitter: MutationEmitter<Mutation>) async {
        switch action {
        case let .increment(value):
            await emitter(.increase(value))
        case let .decrement(value):
            await emitter(.decrease(value))
        }
    }
    
    func reduce(in state: State, mutation: Mutation) -> State {
        var newState = state
        switch mutation {
        case let .increase(value):
            newState.counter += value
        case let .decrease(value):
            newState.counter -= value
        }
        return newState
    }
}

@Test func testIncreamentAndDecrement() async throws {
    let testStore = await TestStore(
        initialState: CounterReducer.State(),
        reducer: CounterReducer()
    )
    
    await testStore.send(action: .increment(1)) {
        $0.counter = 1
    }
    
    await testStore.send(action: .decrement(1)) {
        $0.counter = 0
    }
    
    let isFailure = await testStore.isFailure
    let failureMessage = await testStore.failureMessage
    
    #expect(isFailure == false, Comment(rawValue: failureMessage))
}
