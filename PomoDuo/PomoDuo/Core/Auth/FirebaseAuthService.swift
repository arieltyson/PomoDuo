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

    func signInAnonymously() async throws -> AuthUser {
        do {
            let result = try await auth.signInAnonymously()
            return Self.makeAuthUser(from: result.user)
        } catch {
            throw mapAuthError(error)
        }
    }

    func signIn(email: String, password: String) async throws -> AuthUser {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedEmail.isEmpty else {
            throw AuthServiceError.invalidEmail
        }
        guard !password.isEmpty else {
            throw AuthServiceError.invalidCredentials
        }

        do {
            let result = try await auth.signIn(withEmail: normalizedEmail, password: password)
            return Self.makeAuthUser(from: result.user)
        } catch {
            throw mapAuthError(error)
        }
    }

    func createAccount(email: String, password: String, displayName: String) async throws -> AuthUser {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)

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
            let result = try await auth.createUser(withEmail: normalizedEmail, password: password)
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

    private static func makeAuthUser(from user: User) -> AuthUser {
        AuthUser(
            id: user.uid,
            displayName: displayName(for: user),
            isAnonymous: user.isAnonymous,
            createdAt: user.metadata.creationDate ?? .now
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
