import Foundation
@preconcurrency import FirebaseAuth

private struct FirebaseAuthStateListenerHandle: @unchecked Sendable {
    nonisolated(unsafe) let value: NSObjectProtocol
}

/// Firebase-backed implementation of ``AuthService``.
@MainActor
final class FirebaseAuthService: AuthService {
    private let auth: Auth

    init(auth: Auth = Auth.auth()) {
        self.auth = auth
    }

    var currentUser: AuthUser? {
        auth.currentUser.map(Self.makeAuthUser(from:))
    }

    // MARK: - Anonymous

    func signInAnonymously() async throws -> AuthUser {
        do {
            let result = try await auth.signInAnonymously()
            return Self.makeAuthUser(from: result.user)
        } catch {
            throw mapAuthError(error)
        }
    }

    // MARK: - Email

    func signIn(email: String, password: String) async throws -> AuthUser {
        let normalizedEmail = email.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !normalizedEmail.isEmpty else {
            throw AuthServiceError.invalidEmail
        }
        guard !password.isEmpty else {
            throw AuthServiceError.invalidCredentials
        }

        do {
            let result = try await auth.signIn(
                withEmail: normalizedEmail,
                password: password
            )
            return Self.makeAuthUser(from: result.user)
        } catch {
            throw mapAuthError(error)
        }
    }

    func createAccount(
        email: String,
        password: String,
        displayName: String
    ) async throws -> AuthUser {
        let normalizedEmail = email.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let normalizedName = displayName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !normalizedEmail.isEmpty else {
            throw AuthServiceError.invalidEmail
        }
        guard !password.isEmpty else {
            throw AuthServiceError.invalidCredentials
        }
        guard !normalizedName.isEmpty else {
            throw AuthServiceError.emptyDisplayName
        }

        do {
            let result = try await auth.createUser(
                withEmail: normalizedEmail,
                password: password
            )
            let profileRequest = result.user.createProfileChangeRequest()
            profileRequest.displayName = normalizedName
            try await profileRequest.commitChanges()
            try await result.user.reload()

            guard let refreshedUser = auth.currentUser else {
                throw AuthServiceError.notAuthenticated
            }

            return Self.makeAuthUser(from: refreshedUser)
        } catch {
            throw mapAuthError(error)
        }
    }

    // MARK: - Sign in with Apple

    func signInWithApple(
        credential: AppleAuthCredential
    ) async throws -> AuthUser {
        let firebaseCredential = OAuthProvider.appleCredential(
            withIDToken: credential.idToken,
            rawNonce: credential.nonce,
            fullName: credential.fullName
        )

        do {
            let result = try await auth.signIn(with: firebaseCredential)
            try await applyFullNameIfNeeded(
                credential.fullName,
                to: result.user
            )
            return Self.makeAuthUser(from: result.user)
        } catch let authError as AuthServiceError {
            throw authError
        } catch {
            throw AuthServiceError.appleSignInFailed(
                error.localizedDescription
            )
        }
    }

    func linkAppleCredential(
        _ credential: AppleAuthCredential
    ) async throws -> AuthUser {
        guard let currentUser = auth.currentUser else {
            throw AuthServiceError.notAuthenticated
        }

        let firebaseCredential = OAuthProvider.appleCredential(
            withIDToken: credential.idToken,
            rawNonce: credential.nonce,
            fullName: credential.fullName
        )

        do {
            let result = try await currentUser.link(with: firebaseCredential)
            try await applyFullNameIfNeeded(
                credential.fullName,
                to: result.user
            )
            return Self.makeAuthUser(from: result.user)
        } catch {
            throw AuthServiceError.credentialLinkingFailed(
                error.localizedDescription
            )
        }
    }

    // MARK: - Account Management

    func signOut() async throws {
        do {
            try auth.signOut()
        } catch {
            throw mapAuthError(error)
        }
    }

    func deleteAccount() async throws {
        guard let user = auth.currentUser else {
            throw AuthServiceError.notAuthenticated
        }

        do {
            try await user.delete()
        } catch {
            throw mapAuthError(error)
        }
    }

    func updateDisplayName(_ name: String) async throws -> AuthUser {
        guard let user = auth.currentUser else {
            throw AuthServiceError.notAuthenticated
        }

        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty else {
            throw AuthServiceError.emptyDisplayName
        }

        do {
            let profileRequest = user.createProfileChangeRequest()
            profileRequest.displayName = normalizedName
            try await profileRequest.commitChanges()
            try await user.reload()

            guard let refreshedUser = auth.currentUser else {
                throw AuthServiceError.notAuthenticated
            }

            return Self.makeAuthUser(from: refreshedUser)
        } catch {
            throw mapAuthError(error)
        }
    }

    // MARK: - State Stream

    func authStateChanges() -> AsyncStream<AuthUser?> {
        let auth = self.auth

        return AsyncStream { continuation in
            let handle = auth.addStateDidChangeListener { _, user in
                continuation.yield(user.map(Self.makeAuthUser(from:)))
            }
            let listenerHandle = FirebaseAuthStateListenerHandle(value: handle)

            continuation.onTermination = { _ in
                auth.removeStateDidChangeListener(listenerHandle.value)
            }
        }
    }

    // MARK: - Helpers

    /// Applies the user's full name from the Apple credential if the
    /// Firebase profile doesn't already have a display name.
    ///
    /// Apple provides the name only on the first authorization, so this
    /// is the one chance to capture it.
    private func applyFullNameIfNeeded(
        _ fullName: PersonNameComponents?,
        to user: User
    ) async throws {
        guard let fullName else { return }

        let formattedName = PersonNameComponentsFormatter
            .localizedString(from: fullName, style: .default)

        guard !formattedName.trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
        else {
            return
        }

        // Only set the name if Firebase doesn't already have one.
        let existingName = user.displayName ?? ""
        guard existingName.trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
        else {
            return
        }

        let profileRequest = user.createProfileChangeRequest()
        profileRequest.displayName = formattedName
        try await profileRequest.commitChanges()
        try await user.reload()
    }

    private static func makeAuthUser(from user: User) -> AuthUser {
        AuthUser(
            id: user.uid,
            displayName: displayName(for: user),
            isAnonymous: user.isAnonymous,
            createdAt: user.metadata.creationDate ?? .now,
            email: user.email,
            authProvider: authProvider(for: user)
        )
    }

    private static func displayName(for user: User) -> String {
        if let displayName = user.displayName,
            !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            return displayName
        }

        if let email = user.email,
            let nameComponent = email.split(separator: "@").first,
            !nameComponent.isEmpty
        {
            return String(nameComponent)
        }

        return "Focus Friend"
    }

    private static func authProvider(for user: User) -> AuthProvider {
        if user.isAnonymous {
            return .anonymous
        }

        let providerIDs = user.providerData.map(\.providerID)
        if providerIDs.contains("apple.com") {
            return .apple
        }
        if providerIDs.contains("password") {
            return .email
        }

        return .email
    }

    private func mapAuthError(_ error: Error) -> Error {
        let nsError = error as NSError
        guard nsError.domain == AuthErrorDomain,
            let authErrorCode = AuthErrorCode(rawValue: nsError.code)
        else {
            return error
        }

        switch authErrorCode {
        case .invalidEmail:
            return AuthServiceError.invalidEmail
        case .wrongPassword, .invalidCredential, .userNotFound:
            return AuthServiceError.invalidCredentials
        case .requiresRecentLogin, .userTokenExpired, .invalidUserToken:
            return AuthServiceError.notAuthenticated
        default:
            return error
        }
    }
}
