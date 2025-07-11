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
public actor TestStore<R: Reducer>: ObservableObject, Identifiable
where R.State: Sendable, R.Action: Sendable {
    public let id: UUID = UUID()
    
    @MainActor
    public private(set) var state: R.State {
        willSet { objectWillChange.send() }
        didSet { continuation.yield(state) }
    }
    
    @MainActor
    public private(set) var taskRegistry = CancellableTaskRegistry<AnyHashable>()
    
    
    /// Report with failed test results
    ///
    /// In order to call XCTFail like TCA, we need to call it arbitrarily at runtime.
    /// https://github.com/braze-inc/xctest-dynamic-overlay/blob/main/Sources/XCTestDynamicOverlay/XCTFail.swift
    ///
    /// Changing the interface structure may cause unexpected results, so it cannot be used.
    ///
    private var reports: [Report] = []
    
    private let reducer: R
    private let continuation: AsyncStream<R.State>.Continuation
    let stream: AsyncStream<R.State>
    
    private let mutationContinuation: AsyncStream<R.Mutation>.Continuation
    private let mutationStream: AsyncStream<R.Mutation>
    
    @MainActor
    public init(initialState: R.State, reducer: R) {
        self.state = initialState
        self.reducer = reducer
        
        (stream, continuation) = AsyncStream<R.State>.makeStream()
        (mutationStream, mutationContinuation) = AsyncStream<R.Mutation>.makeStream()
        
        continuation.yield(state)
    }
    
    public func send(isolation: isolated (any Actor)? = #isolation, action: R.Action, assert: (@Sendable (inout R.State) -> Void)? = nil) async {
        let (mutationStream, mutationContinuation) = AsyncStream<R.Mutation>.makeStream()
        let emitter = MutationEmitter<R.Mutation>(continuation: .init(mutationContinuation))

        let reducerTask = Task {
            for await mutation in mutationStream {
                var currentState = await state
                let newState = await reducer.reduce(in: await state, mutation: mutation)
                
                // MainActor context에서 assert 수행
                if let assert = assert {
                    await MainActor.run {
                        var snapshot = currentState
                        assert(&snapshot)
                        Task { @MainActor in
                            await assertStateNoDifference(newState, snapshot)
                        }
                    }
                }

                await MainActor.run { self.state = newState }
            }
        }

        await reducer.mutate(isolation: #isolation, action: action, emitter: emitter)

        mutationContinuation.finish()
        await reducerTask.value
    }
    
    private func assertStateNoDifference(_ s1: R.State, _ s2: R.State) {
        if s1 != s2 {
            reports.append(Report(actual: s1, expected: s2))
        }
    }
    
    var isFailure: Bool {
        return reports.count > 0
    }
    
    var failureMessage: String {
        return reports.map(\.message).joined(separator: ", ")
    }
}

extension TestStore {
    struct Report: Sendable {
        let actual: R.State
        let expected: R.State
        
        let message: String
        
        init(actual: R.State, expected: R.State, message: String = "") {
            self.actual = actual
            self.expected = expected
            
            if message.isEmpty {
                self.message = """
                
                ❗ Test failed: State did not match expectation
                
                🔴 Actual   state  : \(Self.dump(actual))
                🟢 Expected state  : \(Self.dump(expected))
                
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
