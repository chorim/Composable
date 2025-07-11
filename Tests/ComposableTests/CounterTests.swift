//
//  CounterTests.swift
//  Composable
//
//  Created by chorim.i on 3/27/25.
//

import Testing
@testable import Composable
import CasePaths

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

fileprivate struct ToggleReducer: Reducer {
    struct State: ViewState { var isOn = false }
    enum Action: Sendable { case toggle }
    enum Mutation: Sendable { case toggled }

    func mutate(isolation: isolated(any Actor)?, action: Action, emitter: MutationEmitter<Mutation>) async {
        if case .toggle = action {
            await emitter.emit(.toggled)
        }
    }

    @MainActor
    func reduce(in state: State, mutation: Mutation) -> State {
        var state = state
        if case .toggled = mutation { state.isOn.toggle() }
        return state
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

fileprivate struct AppState: ViewState {
    var counter = CounterReducer.State()
    var toggle = ToggleReducer.State()
}

@CasePathable
fileprivate enum AppAction: Sendable {
    case counter(CounterReducer.Action)
    case toggle(ToggleReducer.Action)
}

@CasePathable
fileprivate enum AppMutation: Sendable {
    case counter(CounterReducer.Mutation)
    case toggle(ToggleReducer.Mutation)
}

@Test func testCombinedReducer() async throws {
    let counterReducer = CounterReducer()
    let toggleReducer = ToggleReducer()
    
    let appCounterReducer = counterReducer.pullback(
        state: \AppState.counter,
        action: \AppAction.Cases.counter,
        mutation: { AppMutation.counter($0) },
        fromGlobalMutation: \AppMutation.Cases.counter
    )
    
    let appToggleReducer = toggleReducer.pullback(
        state: \AppState.toggle,
        action: \AppAction.Cases.toggle,
        mutation: { AppMutation.toggle($0) },
        fromGlobalMutation: \AppMutation.Cases.toggle
    )
    
    let testStore = await TestStore(
        initialState: .init(),
        reducer: CombinedReducer([
            AnyReducer(appCounterReducer),
            AnyReducer(appToggleReducer)
        ])
    )
    
    await testStore.send(action: .counter(.increment(1))) {
        $0.counter.counter = 1
    }
    
    await testStore.send(action: .counter(.decrement(1))) {
        $0.counter.counter = 0
    }
    
    await testStore.send(action: .toggle(.toggle)) {
        $0.toggle.isOn = true
        $0.counter.counter = 0
    }
    
    await testStore.send(action: .counter(.increment(9999))) {
        $0.toggle.isOn = true
        $0.counter.counter = 9999
    }
    
    let isFailure = await testStore.isFailure
    let failureMessage = await testStore.failureMessage
    
    #expect(isFailure == false, Comment(rawValue: failureMessage))
}
