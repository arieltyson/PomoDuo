//
//  FocusIntentState.swift
//  PomoDuo
//
//  Created by Codex on 2/15/26.
//

import Observation

/// Shared bridge between App Intents and the in-app timer UI.
@MainActor
@Observable
final class FocusIntentState {
    /// Global shared instance used by intents and SwiftUI environment injection.
    static let shared = FocusIntentState()

    /// Indicates a pending request to start a focus session.
    private(set) var pendingFocusRequest = false

    private init() {}

    func requestStartFocus() {
        pendingFocusRequest = true
    }

    /// Consumes and clears a pending request.
    /// - Returns: `true` when a pending request existed and was consumed.
    @discardableResult
    func consumeStartFocusRequest() -> Bool {
        guard pendingFocusRequest else { return false }
        pendingFocusRequest = false
        return true
    }
}
