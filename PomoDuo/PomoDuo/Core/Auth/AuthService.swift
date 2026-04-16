import Foundation

/// Typed auth errors shared by auth service implementations.
enum AuthServiceError: LocalizedError, Sendable {
    case invalidCredentials
    case invalidEmail
    case emptyDisplayName
    case notAuthenticated
    case appleSignInFailed(String)
    case credentialLinkingFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            "The credentials are invalid."
        case .invalidEmail:
            "Enter a valid email address."
        case .emptyDisplayName:
            "Display name cannot be empty."
        case .notAuthenticated:
            "No authenticated user is available."
        case .appleSignInFailed(let reason):
            "Sign in with Apple failed: \(reason)"
        case .credentialLinkingFailed(let reason):
            "Could not link Apple ID: \(reason)"
        }
    }
}

/// Backend-agnostic contract for authentication.
protocol AuthService: Sendable {
    /// Currently signed-in identity, if any.
    var currentUser: AuthUser? { get async }

    /// Signs in anonymously.
    func signInAnonymously() async throws -> AuthUser

    /// Signs in with email credentials.
    func signIn(email: String, password: String) async throws -> AuthUser

    /// Creates a new account.
    func createAccount(email: String, password: String, displayName: String)
        async throws -> AuthUser

    /// Signs in with an Apple credential (new user or returning user).
    func signInWithApple(credential: AppleAuthCredential) async throws
        -> AuthUser

    /// Links an Apple credential to the current anonymous account,
    /// preserving the existing user ID and all associated data.
    func linkAppleCredential(_ credential: AppleAuthCredential) async throws
        -> AuthUser

    /// Signs out the active user.
    func signOut() async throws

    /// Deletes the active account.
    func deleteAccount() async throws

    /// Updates display name for the active account.
    func updateDisplayName(_ name: String) async throws -> AuthUser

    /// Forces a server-authoritative refresh of the current user's profile
    /// and returns the up-to-date identity.
    ///
    /// This exists as a **pull channel** for same-identity profile changes.
    /// The identity stream ``authStateChanges()`` intentionally filters out
    /// same-id replays at the ``AuthManager`` layer to prevent stale
    /// subscription-time snapshots from clobbering direct writes, which
    /// means genuine profile updates delivered on that stream would also be
    /// dropped. Calling this method explicitly asks for a fresh read and
    /// signals intent to accept the result even when the identity is the
    /// same.
    ///
    /// Implementations should reload from the backend's authoritative source
    /// (e.g. `FIRUser.reload()`) when available. Returns `nil` when no user
    /// is currently signed in.
    func refreshCurrentUser() async throws -> AuthUser?

    /// Emits auth state whenever it changes.
    func authStateChanges() -> AsyncStream<AuthUser?>
}
