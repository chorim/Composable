//
//  TestStore.swift
//  Composable
//
//  Created by chorim.i on 3/27/25.
//
import Foundation
import Combine

/// TestStore Interface
///
/// Create a test store by passing in a Reducer and State to run the test.
/// ```
/// let testStore = TestStore(state: State, reducer: Reducer)
/// ```
///
/// Write the test code.
/// After passing in the intended Action, the test succeeds if the result is the same as State.
///
/// ```
/// await testStore.send(.increase) {
///     $0.count = 1
/// }
///
/// await testStore.send(.decrease) {
///     $0.count = 0
/// }
///
/// await XCTAssertStore(testStore) // Test succeeds.
/// ```
///
/// If you pass the intended Action as shown below, but it is different from the State, the test will fail.
///
/// ```
/// await testStore.send(.increase) {
///     $0.count = 0
/// }
///
/// await XCTAssertStore(testStore) // Test fail.
/// ```
public actor TestStore<R: Reducer & Sendable, S: ViewState, A: Sendable>: ObservableObject, Identifiable, Equatable {
    public let id: UUID = UUID()
    
    @MainActor
    private(set) var state: S {
        willSet {
            objectWillChange.send()
        }
    }
    
    /// Report with failed test results
    ///
    /// In order to call XCTFail like TCA, we need to call it arbitrarily at runtime.
    /// https://github.com/braze-inc/xctest-dynamic-overlay/blob/main/Sources/XCTestDynamicOverlay/XCTFail.swift
    ///
    /// Changing the interface structure may cause unexpected results, so it cannot be used.
    ///
    private var reports: [Report] = []
    
    private let reducer: R
    
    init(state: S, reducer: R) where R.State == S, R.Action == A {
        self.state = state
        self.reducer = reducer
    }
    
    public func send(action: sending A, assert: ((inout S) -> Void)? = nil) async where R: Sendable, R.State == S, R.Action == A {
        var currentState = await state

        let newState = await reducer.reduce(in: currentState, action: action)

        assert?(&currentState)
        
        await MainActor.run { state = newState }
        
        if assert != nil {
            assertStateNoDifference(newState, currentState)
        }
    }
    
    private func assertStateNoDifference(_ s1: S, _ s2: S) {
        if s1 != s2 {
            reports.append(Report(expected: s1, failure: s2))
        }
    }
    
    var isFailure: Bool {
        return reports.count > 0
    }
    
    var failureMessage: String {
        return reports.map(\.message).joined(separator: ", ")
    }
    
    // MARK: - Equatable
    public static func == (lhs: TestStore<R, S, A>, rhs: TestStore<R, S, A>) -> Bool {
        return lhs.id == rhs.id
    }
}

extension TestStore {
    struct Report: Sendable {
        let expected: S
        let failure: S
        
        let message: String
        
        init(expected: S, failure: S, message: String = "") {
            self.expected = expected
            self.failure = failure
            
            if message.isEmpty {
                self.message = """
                
                ❗ Expected to be a success but got a failure.
                
                ✅ Expected : \(Self.dump(expected))
                💩 Failure  : \(Self.dump(failure))
                
                """
            } else {
                self.message = message
            }
        }
        
        private static func dump(_ toDump: Any) -> String {
            // TODO: We need to make it easier to visually see the change in state.
            return String(describing: toDump)
        }
    }
}
