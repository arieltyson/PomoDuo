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
    func startsSignedOut() {
        let service = makeService()
        let currentUser = service.currentUser
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
        let secondUser = service.currentUser

        #expect(firstUser.id == secondUser?.id)
        #expect(firstUser.displayName == secondUser?.displayName)
        #expect(firstUser.isAnonymous == secondUser?.isAnonymous)
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

        #expect(service.currentUser == nil)
    }

    @Test("Auth state stream emits sign-in and sign-out changes")
    func streamEmitsStateChanges() async throws {
        let service = makeService()
        let stream = service.authStateChanges()
        var iterator = stream.makeAsyncIterator()

        guard let initial = await iterator.next() else {
            Issue.record("Stream ended unexpectedly before initial emit")
            return
        }
        #expect(initial == nil)

        let user = try await service.signInAnonymously()

        guard let signedIn = await iterator.next() else {
            Issue.record("Stream ended unexpectedly after sign-in")
            return
        }
        #expect(signedIn?.id == user.id)

        try await service.signOut()

        guard let signedOut = await iterator.next() else {
            Issue.record("Stream ended unexpectedly after sign-out")
            return
        }
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

    /// Regression: `start()` must bootstrap the identity before subscribing
    /// to the auth state stream.
    ///
    /// Before the fix, the stream's initial `nil` emission (yielded at
    /// subscription time) could land in the listener *after* a direct
    /// `authState = .signedIn(...)` mutation and regress the state to
    /// `.signedOut`, causing `AccountViewModelTests.savePropagatesDisplayName`
    /// to intermittently read a stale `currentUser`.
    @Test("Start is race-free across direct mutations and stream emissions")
    func startIsRaceFreeAcrossDirectAndStream() async throws {
        let manager = makeManager()
        await manager.start()

        // An immediate direct mutation after start() must not be clobbered
        // by any buffered initial-nil emission from the stream listener.
        await manager.updateDisplayName("Focused Friend")
        #expect(manager.currentUser?.displayName == "Focused Friend")

        // Yield long enough for any backlogged emissions to drain. If the
        // listener had subscribed before bootstrap, this is where the
        // buffered `nil` would replay and flip `authState` to `.signedOut`.
        try await Task.sleep(for: .milliseconds(50))

        #expect(manager.isSignedIn)
        #expect(manager.currentUser?.displayName == "Focused Friend")
    }

    /// Regression: a stream emission carrying an older snapshot of the
    /// same identity must not overwrite a newer direct write.
    ///
    /// The listener buffers `currentUser` at subscription time. If the
    /// listener runs that initial emission *after* `updateDisplayName`'s
    /// direct write lands, it would otherwise regress the displayName back
    /// to the pre-update value. This test directly triggers the stale
    /// replay via a manually-constructed emission.
    @Test("Stream emissions do not regress direct profile writes")
    func streamDoesNotRegressDirectProfileWrites() async throws {
        let manager = makeManager()
        await manager.start()

        guard let initialUser = manager.currentUser else {
            Issue.record("Expected signed-in user after start()")
            return
        }

        await manager.updateDisplayName("Fresh Name")
        #expect(manager.currentUser?.displayName == "Fresh Name")

        // Replay the initial (stale) user snapshot as if the listener had
        // just now drained its subscription-time buffer.
        manager.simulateStreamEmissionForTests(initialUser)

        #expect(manager.currentUser?.displayName == "Fresh Name")
        #expect(manager.currentUser?.id == initialUser.id)
    }
}
