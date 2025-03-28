//
//  Store+Binding.swift
//  Composable
//
//  Created by chorim.i on 3/27/25.
//
#if canImport(SwiftUI)
import SwiftUI

extension Store {
    @MainActor
    public func binding<V>(
        get: @escaping (S) -> V,
        send action: @escaping (V) -> Void
    ) -> Binding<V> where V: Equatable {
        Binding(
            get: { [unowned self] in
                return get(self.state)
            },
            set: { newValue in
                if get(self.state) != newValue {
                    action(newValue)
                }
            }
        )
    }
    
    @MainActor
    public func binding<V>(
        get: @escaping (S) -> V,
        compactSend action: @escaping (V) -> A
    ) -> Binding<V> where R.State == S, R.Action == A, V: Equatable {
        Binding(
            get: { [unowned self] in get(self.state) },
            set: { [unowned self] newValue in
                if get(self.state) != newValue {
                    Task {
                        await self.send(action: action(newValue))
                    }
                }
            }
        )
    }
}
#endif
