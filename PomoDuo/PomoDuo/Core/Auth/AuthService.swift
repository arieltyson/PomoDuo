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

    /// Emits auth state whenever it changes.
    func authStateChanges() -> AsyncStream<AuthUser?>
}
