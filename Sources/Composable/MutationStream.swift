//
//  MutationStream.swift
//  Composable
//
//  Created by chorim.i on 6/11/25.
//
import Foundation

public struct MutationEmitter<Mutation: Sendable>: Sendable {
    private let continuation: MutationStreamContinuation<Mutation>

    public init(continuation: MutationStreamContinuation<Mutation>) {
        self.continuation = continuation
    }
    
    public init(stream: AsyncStream<Mutation>) {
        let (_, continuation) = AsyncStream<Mutation>.makeStream()
        self.continuation = MutationStreamContinuation(continuation)
    }

//    @discardableResult
//    public func emit(
//        _ mutation: Mutation,
//        isolation: isolated (any Actor)? = #isolation
//    ) async -> EffectTaskChain<Mutation, Mutation, Never> {
//        await continuation.emit(mutation)
//        return EffectTaskChain(result: .success(mutation), emitter: self)
//    }
    
    public func emit(
        _ mutation: Mutation,
        isolation: isolated (any Actor)? = #isolation
    ) async {
        await continuation.emit(mutation)
    }
    
    public func callAsFunction(_ mutation: Mutation) async {
        await continuation.emit(mutation)
    }
}

public actor MutationStreamContinuation<Mutation: Sendable> {
    private var continuation: AsyncStream<Mutation>.Continuation

    public init(_ base: AsyncStream<Mutation>.Continuation) {
        continuation = base
    }

    public func emit(_ mutation: Mutation) {
        continuation.yield(mutation)
    }

    public func yield(_ element: Mutation) {
        continuation.yield(element)
    }

    public func finish() {
        continuation.finish()
    }
}
