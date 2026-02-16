//
//  AuthUser.swift
//  PomoDuo
//
//  Created by Codex on 2/16/26.
//

import Foundation

/// Lightweight authenticated identity used throughout the app.
struct AuthUser: Equatable, Sendable, Identifiable {
    /// Provider identifier (Firebase UID in the real implementation).
    let id: String

    /// Human-readable display name shown in the UI.
    let displayName: String

    /// Whether this identity is anonymous/guest.
    let isAnonymous: Bool

    /// Account creation timestamp.
    let createdAt: Date
}
