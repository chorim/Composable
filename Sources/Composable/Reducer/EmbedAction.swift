//
//  EmbedAction.swift
//  Composable
//
//  Created by Insu Byeon on 4/3/25.
//
import Foundation

public enum EmbedAction<A: Sendable>: Sendable {
    case concat([A])
    case none
}
