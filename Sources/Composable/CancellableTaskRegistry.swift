//
//  CancellableTaskRegistry.swift
//  Composable
//
//  Created by chorim.i on 7/11/25.
//
import Foundation

@MainActor
final public class CancellableTaskRegistry<ID: Hashable> {
    private var tasks: [ID: Task<Void, Never>] = [:]

    public subscript(id: ID) -> Task<Void, Never>? {
        get { tasks[id] }
        set { tasks[id] = newValue }
    }

    public func cancel(id: ID) {
        tasks[id]?.cancel()
        tasks[id] = nil
    }

    public func cancelAll() {
        tasks.values.forEach { $0.cancel() }
        tasks.removeAll()
    }
}

extension Task where Success == Void, Failure == Never {
    @MainActor
    public func cancellable<ID: Hashable>(id: ID, in store: CancellableTaskRegistry<ID>) {
        store[id] = self
    }
}
