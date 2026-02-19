import Foundation
import Testing

@testable import PomoDuo

@Suite("AuthUser")
@MainActor
struct AuthUserTests {
    @Test("Stores identity properties")
    func storesProperties() {
        let createdAt = Date.now
        let user = AuthUser(
            id: "auth-123",
            displayName: "Focus Friend",
            isAnonymous: true,
            createdAt: createdAt
        )

        #expect(user.id == "auth-123")
        #expect(user.displayName == "Focus Friend")
        #expect(user.isAnonymous)
        #expect(user.createdAt == createdAt)
    }
}

@Suite("MockAuthService")
@MainActor
struct MockAuthServiceTests {
    private func makeDefaults() -> UserDefaults {
        let suiteName = "com.pomoduo.tests.auth.\(UUID().uuidString)"
        if let defaults = UserDefaults(suiteName: suiteName) {
            defaults.removePersistentDomain(forName: suiteName)
            return defaults
        }

        return .standard
    }

    private func makeService() -> MockAuthService {
        MockAuthService(
            simulatedDelay: .zero,
            userDefaults: makeDefaults()
        )
    }

    @Test("Starts signed out")
    func startsSignedOut() async {
        let service = makeService()
        let currentUser = await service.currentUser
        #expect(currentUser == nil)
    }

    @Test("Anonymous sign-in creates and persists a user")
    func anonymousSignInPersists() async throws {
        let defaults = makeDefaults()
        let service = MockAuthService(
            simulatedDelay: .zero,
            userDefaults: defaults
        )

        let firstUser = try await service.signInAnonymously()
        let secondUser = await service.currentUser

        #expect(firstUser == secondUser)
        #expect(firstUser.isAnonymous)
    }

    @Test("Email sign-in returns non-anonymous user")
    func emailSignInReturnsUser() async throws {
        let service = makeService()

        let user = try await service.signIn(
            email: "hello@example.com",
            password: "test"
        )

        #expect(user.isAnonymous == false)
        #expect(user.displayName == "hello")
    }

    @Test("Sign-out clears user")
    func signOutClearsUser() async throws {
        let service = makeService()

        _ = try await service.signInAnonymously()
        try await service.signOut()

        #expect(await service.currentUser == nil)
    }

    @Test("Auth state stream emits sign-in and sign-out changes")
    func streamEmitsStateChanges() async throws {
        let service = makeService()
        let stream = service.authStateChanges()
        var iterator = stream.makeAsyncIterator()

        let initial = await iterator.next()
        #expect(initial == nil)

        let user = try await service.signInAnonymously()
        let signedIn = await iterator.next() ?? nil
        #expect(signedIn?.id == user.id)

        try await service.signOut()
        let signedOut = await iterator.next()
        #expect(signedOut == nil)
    }
}

@Suite("AuthManager")
@MainActor
struct AuthManagerTests {
    private func makeManager() -> AuthManager {
        let suiteName = "com.pomoduo.tests.auth.manager.\(UUID().uuidString)"
        let defaults: UserDefaults
        if let suiteDefaults = UserDefaults(suiteName: suiteName) {
            suiteDefaults.removePersistentDomain(forName: suiteName)
            defaults = suiteDefaults
        } else {
            defaults = .standard
        }

        let service = MockAuthService(
            simulatedDelay: .zero,
            userDefaults: defaults
        )
        return AuthManager(authService: service)
    }

    @Test("Initial state is unknown")
    func initialStateIsUnknown() {
        let manager = makeManager()

        #expect(manager.authState == .unknown)
        #expect(manager.currentUser == nil)
        #expect(manager.currentUserID == nil)
    }

    @Test("Start auto signs in anonymously")
    func startAutoSignsIn() async {
        let manager = makeManager()
        await manager.start()

        #expect(manager.isSignedIn)
        #expect(manager.currentUser?.isAnonymous == true)
        #expect(manager.currentUserID != nil)
    }

    @Test("Sign-out transitions to signed out state")
    func signOutTransitionsToSignedOut() async {
        let manager = makeManager()
        await manager.start()
        await manager.signOut()

        #expect(manager.authState == .signedOut)
        #expect(manager.currentUser == nil)
    }

    @Test("Email sign-in updates identity")
    func emailSignInUpdatesIdentity() async {
        let manager = makeManager()
        await manager.signIn(email: "study@example.com", password: "password")

        #expect(manager.currentUser?.isAnonymous == false)
        #expect(manager.currentUser?.displayName == "study")
    }

    @Test("Update display name modifies current user")
    func updateDisplayNameModifiesCurrentUser() async {
        let manager = makeManager()
        await manager.start()
        await manager.updateDisplayName("Ariel")

        #expect(manager.currentUser?.displayName == "Ariel")
    }
}
