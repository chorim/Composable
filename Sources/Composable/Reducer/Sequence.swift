//
//  Sequence.swift
//  Composable
//
//  Created by Insu Byeon on 4/3/25.
//
import Foundation

public struct _Sequence<R0: Reducer, R1: Reducer>: Reducer where R0.State == R1.State, R0.Action == R1.Action {
    @usableFromInline
    let r0: R0
    
    @usableFromInline
    let r1: R1
    
    public init(_ r0: R0, _ r1: R1) {
        self.r0 = r0
        self.r1 = r1
    }
    
    @inlinable
    public func reduce(in state: R0.State, action: R0.Action) async -> R0.State {
        var unownedState: R0.State = state
        unownedState = await r0.reduce(in: state, action: action)
        unownedState = await r1.reduce(in: unownedState, action: action)
        return unownedState
    }
}
