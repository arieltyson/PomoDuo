import Foundation

/// Local, persistence-backed auth service used until Firebase is integrated.
@MainActor
final class MockAuthService: AuthService {
    private enum Keys {
        static let userID = "com.pomoduo.mockAuth.userID"
        static let displayName = "com.pomoduo.mockAuth.displayName"
        static let isAnonymous = "com.pomoduo.mockAuth.isAnonymous"
        static let createdAt = "com.pomoduo.mockAuth.createdAt"
        static let email = "com.pomoduo.mockAuth.email"
        static let authProvider = "com.pomoduo.mockAuth.authProvider"
    }

    private let simulatedDelay: Duration
    private let userDefaults: UserDefaults
    private var continuations: [UUID: AsyncStream<AuthUser?>.Continuation] = [:]

    init(
        simulatedDelay: Duration = .milliseconds(250),
        userDefaults: UserDefaults = .standard
    ) {
        self.simulatedDelay = simulatedDelay
        self.userDefaults = userDefaults
    }

    var currentUser: AuthUser? {
        guard let id = userDefaults.string(forKey: Keys.userID) else {
            return nil
        }

        let displayName =
            userDefaults.string(forKey: Keys.displayName) ?? "Focus Friend"
        let isAnonymous = userDefaults.bool(forKey: Keys.isAnonymous)
        let createdAtEpoch = userDefaults.double(forKey: Keys.createdAt)
        let createdAt = Date(
            timeIntervalSince1970: createdAtEpoch == 0
                ? Date.now.timeIntervalSince1970 : createdAtEpoch
        )
        let email = userDefaults.string(forKey: Keys.email)
        let providerRaw = userDefaults.string(forKey: Keys.authProvider)
        let authProvider: AuthProvider
        if let providerRaw, let provider = AuthProvider(rawValue: providerRaw) {
            authProvider = provider
        } else {
            authProvider = isAnonymous ? .anonymous : .email
        }

        return AuthUser(
            id: id,
            displayName: displayName,
            isAnonymous: isAnonymous,
            createdAt: createdAt,
            email: email,
            authProvider: authProvider
        )
    }

    func signInAnonymously() async throws -> AuthUser {
        try await Task.sleep(for: simulatedDelay)

        if let existing = currentUser {
            emitStateChange(existing)
            return existing
        }

        let user = AuthUser(
            id: "mock-\(UUID().uuidString.lowercased())",
            displayName: "Focus Friend",
            isAnonymous: true,
            createdAt: .now,
            authProvider: .anonymous
        )

        persist(user)
        emitStateChange(user)
        return user
    }

    func signIn(email: String, password: String) async throws -> AuthUser {
        try await Task.sleep(for: simulatedDelay)

        let normalizedEmail = email.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).localizedLowercase
        guard normalizedEmail.contains("@") else {
            throw AuthServiceError.invalidEmail
        }
        guard !password.isEmpty else {
            throw AuthServiceError.invalidCredentials
        }

        let defaultName =
            normalizedEmail.split(separator: "@").first.map(String.init)
            ?? "Focus Friend"
        let user = AuthUser(
            id: "mock-email-\(sanitizedIdentifier(from: normalizedEmail))",
            displayName: defaultName,
            isAnonymous: false,
            createdAt: currentUser?.createdAt ?? .now,
            email: normalizedEmail,
            authProvider: .email
        )

        persist(user)
        emitStateChange(user)
        return user
    }

    func createAccount(email: String, password: String, displayName: String)
        async throws -> AuthUser
    {
        try await Task.sleep(for: simulatedDelay)

        let normalizedEmail = email.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).localizedLowercase
        let normalizedName = displayName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard normalizedEmail.contains("@") else {
            throw AuthServiceError.invalidEmail
        }
        guard !password.isEmpty else {
            throw AuthServiceError.invalidCredentials
        }
        guard !normalizedName.isEmpty else {
            throw AuthServiceError.emptyDisplayName
        }

        let user = AuthUser(
            id: "mock-email-\(sanitizedIdentifier(from: normalizedEmail))",
            displayName: normalizedName,
            isAnonymous: false,
            createdAt: .now,
            email: normalizedEmail,
            authProvider: .email
        )

        persist(user)
        emitStateChange(user)
        return user
    }

    func signInWithApple(
        credential: AppleAuthCredential
    ) async throws -> AuthUser {
        try await Task.sleep(for: simulatedDelay)

        let name: String
        if let fullName = credential.fullName {
            let formatted = PersonNameComponentsFormatter
                .localizedString(from: fullName, style: .default)
            name = formatted.isEmpty ? "Apple User" : formatted
        } else {
            name = currentUser?.displayName ?? "Apple User"
        }

        let identifierSeed =
            credential.email?.localizedLowercase ?? credential.idToken
        let identifierComponent = sanitizedIdentifier(from: identifierSeed)
        let fallbackID = UUID().uuidString.lowercased()
        let userID =
            identifierComponent.isEmpty
            ? "mock-apple-\(fallbackID)"
            : "mock-apple-\(identifierComponent)"

        let user = AuthUser(
            id: userID,
            displayName: name,
            isAnonymous: false,
            createdAt: currentUser?.createdAt ?? .now,
            email: credential.email,
            authProvider: .apple
        )

        persist(user)
        emitStateChange(user)
        return user
    }

    func linkAppleCredential(
        _ credential: AppleAuthCredential
    ) async throws -> AuthUser {
        try await Task.sleep(for: simulatedDelay)

        guard let existing = currentUser else {
            throw AuthServiceError.notAuthenticated
        }

        let name: String
        if let fullName = credential.fullName {
            let formatted = PersonNameComponentsFormatter
                .localizedString(from: fullName, style: .default)
            name = formatted.isEmpty ? existing.displayName : formatted
        } else {
            name = existing.displayName
        }

        // Linking preserves the original user ID to keep existing
        // partnerships, session history, and scoped data references intact.
        let upgraded = AuthUser(
            id: existing.id,
            displayName: name,
            isAnonymous: false,
            createdAt: existing.createdAt,
            email: credential.email ?? existing.email,
            authProvider: .apple
        )

        persist(upgraded)
        emitStateChange(upgraded)
        return upgraded
    }

    func signOut() async throws {
        clearPersistedUser()
        emitStateChange(nil)
    }

    func deleteAccount() async throws {
        clearPersistedUser()
        emitStateChange(nil)
    }

    func updateDisplayName(_ name: String) async throws -> AuthUser {
        try await Task.sleep(for: simulatedDelay)

        guard let existing = currentUser else {
            throw AuthServiceError.notAuthenticated
        }

        let normalizedName = name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !normalizedName.isEmpty else {
            throw AuthServiceError.emptyDisplayName
        }

        let updated = AuthUser(
            id: existing.id,
            displayName: normalizedName,
            isAnonymous: existing.isAnonymous,
            createdAt: existing.createdAt,
            email: existing.email,
            authProvider: existing.authProvider
        )

        persist(updated)
        emitStateChange(updated)
        return updated
    }

    /// Mirrors the Firebase `User.reload()` contract: returns the current
    /// persisted profile, or `nil` when no user is signed in. The mock
    /// already re-reads from ``UserDefaults`` on every access, so this is
    /// equivalent to reading ``currentUser``.
    func refreshCurrentUser() async throws -> AuthUser? {
        try await Task.sleep(for: simulatedDelay)
        return currentUser
    }

    func authStateChanges() -> AsyncStream<AuthUser?> {
        AsyncStream { continuation in
            let subscriptionID = UUID()
            continuations[subscriptionID] = continuation
            continuation.yield(currentUser)

            continuation.onTermination = { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.removeContinuation(id: subscriptionID)
                }
            }
        }
    }

    // MARK: - Persistence Helpers

    private func sanitizedIdentifier(from value: String) -> String {
        String(
            value.localizedLowercase.map { character in
                character.isLetter || character.isNumber ? character : "_"
            }
        )
    }

    private func persist(_ user: AuthUser) {
        userDefaults.set(user.id, forKey: Keys.userID)
        userDefaults.set(user.displayName, forKey: Keys.displayName)
        userDefaults.set(user.isAnonymous, forKey: Keys.isAnonymous)
        userDefaults.set(
            user.createdAt.timeIntervalSince1970,
            forKey: Keys.createdAt
        )
        if let email = user.email {
            userDefaults.set(email, forKey: Keys.email)
        } else {
            userDefaults.removeObject(forKey: Keys.email)
        }
        userDefaults.set(user.authProvider.rawValue, forKey: Keys.authProvider)
    }

    private func clearPersistedUser() {
        userDefaults.removeObject(forKey: Keys.userID)
        userDefaults.removeObject(forKey: Keys.displayName)
        userDefaults.removeObject(forKey: Keys.isAnonymous)
        userDefaults.removeObject(forKey: Keys.createdAt)
        userDefaults.removeObject(forKey: Keys.email)
        userDefaults.removeObject(forKey: Keys.authProvider)
    }

    private func emitStateChange(_ user: AuthUser?) {
        for continuation in continuations.values {
            continuation.yield(user)
        }
    }

    private func removeContinuation(id: UUID) {
        continuations.removeValue(forKey: id)
    }
}
