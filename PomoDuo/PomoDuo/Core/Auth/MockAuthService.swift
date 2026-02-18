import Foundation

/// Local, persistence-backed auth service used until Firebase is integrated.
@MainActor
final class MockAuthService: AuthService {
    private enum Keys {
        static let userID = "com.pomoduo.mockAuth.userID"
        static let displayName = "com.pomoduo.mockAuth.displayName"
        static let isAnonymous = "com.pomoduo.mockAuth.isAnonymous"
        static let createdAt = "com.pomoduo.mockAuth.createdAt"
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

        return AuthUser(
            id: id,
            displayName: displayName,
            isAnonymous: isAnonymous,
            createdAt: createdAt
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
            createdAt: .now
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
            createdAt: currentUser?.createdAt ?? .now
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
            createdAt: .now
        )

        persist(user)
        emitStateChange(user)
        return user
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
            createdAt: existing.createdAt
        )

        persist(updated)
        emitStateChange(updated)
        return updated
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

    private func sanitizedIdentifier(from value: String) -> String {
        value.replacing("@", with: "_").replacing(".", with: "_")
    }

    private func persist(_ user: AuthUser) {
        userDefaults.set(user.id, forKey: Keys.userID)
        userDefaults.set(user.displayName, forKey: Keys.displayName)
        userDefaults.set(user.isAnonymous, forKey: Keys.isAnonymous)
        userDefaults.set(
            user.createdAt.timeIntervalSince1970,
            forKey: Keys.createdAt
        )
    }

    private func clearPersistedUser() {
        userDefaults.removeObject(forKey: Keys.userID)
        userDefaults.removeObject(forKey: Keys.displayName)
        userDefaults.removeObject(forKey: Keys.isAnonymous)
        userDefaults.removeObject(forKey: Keys.createdAt)
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
