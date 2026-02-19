import Foundation

/// How the user authenticated with the app.
enum AuthProvider: String, Sendable, Equatable {
    /// Anonymous/guest session — no persistent identity.
    case anonymous

    /// Sign in with Apple — persistent, App Store-compliant identity.
    case apple

    /// Email and password — legacy or alternative sign-in.
    case email
}

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

    /// User's email address, if available.
    let email: String?

    /// How the user authenticated.
    let authProvider: AuthProvider

    /// Whether this account is linked to a persistent identity
    /// that survives app reinstalls.
    var isPersistent: Bool {
        !isAnonymous
    }

    init(
        id: String,
        displayName: String,
        isAnonymous: Bool,
        createdAt: Date,
        email: String? = nil,
        authProvider: AuthProvider = .anonymous
    ) {
        self.id = id
        self.displayName = displayName
        self.isAnonymous = isAnonymous
        self.createdAt = createdAt
        self.email = email
        self.authProvider = authProvider
    }
}
