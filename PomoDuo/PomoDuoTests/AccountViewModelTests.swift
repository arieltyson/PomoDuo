import Foundation
import Testing

@testable import PomoDuo

@Suite("AccountViewModel")
@MainActor
struct AccountViewModelTests {
    private func makeDefaults() -> UserDefaults {
        let suiteName = "com.pomoduo.tests.account.\(UUID().uuidString)"
        if let defaults = UserDefaults(suiteName: suiteName) {
            defaults.removePersistentDomain(forName: suiteName)
            return defaults
        }

        return .standard
    }

    private func makeAuthManager() -> AuthManager {
        let service = MockAuthService(
            simulatedDelay: .zero,
            userDefaults: makeDefaults()
        )
        return AuthManager(authService: service)
    }

    private func makeSignedInManager() async -> AuthManager {
        let manager = makeAuthManager()
        await manager.start()
        return manager
    }

    @Test("Leaves placeholder display name out of the editable draft")
    func hidesPlaceholderDisplayName() async {
        let manager = await makeSignedInManager()
        let viewModel = AccountViewModel(authManager: manager)

        #expect(viewModel.editingDisplayName.isEmpty)
    }

    @Test("Seeds editable name from a custom signed-in user")
    func seedsCustomDisplayName() async {
        let manager = await makeSignedInManager()
        await manager.updateDisplayName("Study Buddy")

        let viewModel = AccountViewModel(authManager: manager)

        #expect(viewModel.editingDisplayName == "Study Buddy")
    }

    @Test("Validation rejects blank names")
    func validationRejectsBlankName() async {
        let manager = await makeSignedInManager()
        let viewModel = AccountViewModel(authManager: manager)
        viewModel.editingDisplayName = "   "

        #expect(viewModel.nameValidationError != nil)
    }

    @Test("Validation rejects names longer than thirty characters")
    func validationRejectsLongName() async {
        let manager = await makeSignedInManager()
        let viewModel = AccountViewModel(authManager: manager)
        viewModel.editingDisplayName = String(repeating: "A", count: 31)

        #expect(viewModel.nameValidationError != nil)
    }

    @Test("Save updates auth manager display name")
    func saveUpdatesDisplayName() async {
        let manager = await makeSignedInManager()
        let viewModel = AccountViewModel(authManager: manager)
        viewModel.editingDisplayName = "Study Buddy"

        await viewModel.saveDisplayName()

        #expect(manager.currentUser?.displayName == "Study Buddy")
        #expect(viewModel.editingDisplayName == "Study Buddy")
    }

    @Test("Save no-ops for unchanged names")
    func saveNoOpForUnchangedName() async {
        let manager = await makeSignedInManager()
        let viewModel = AccountViewModel(authManager: manager)

        await viewModel.saveDisplayName()

        #expect(manager.currentUser?.displayName == "Focus Friend")
    }

    @Test("Reset clears the placeholder display name draft")
    func resetDisplayName() async {
        let manager = await makeSignedInManager()
        let viewModel = AccountViewModel(authManager: manager)
        viewModel.editingDisplayName = "Changed"

        viewModel.resetDisplayName()

        #expect(viewModel.editingDisplayName.isEmpty)
    }

    @Test("Save propagates display name to friend service")
    func savePropagatesDisplayName() async {
        let manager = await makeSignedInManager()
        let spy = SpyFriendService()
        let viewModel = AccountViewModel(
            authManager: manager,
            friendService: spy
        )
        viewModel.editingDisplayName = "New Name"

        await viewModel.saveDisplayName()

        #expect(manager.currentUser?.displayName == "New Name")
        #expect(spy.propagatedName == "New Name")
    }

    @Test("Save does not propagate when auth update fails")
    func saveDoesNotPropagateOnAuthFailure() async {
        let manager = await makeSignedInManager()
        // Sign out so the update has no user to update
        await manager.signOut()
        let spy = SpyFriendService()
        let viewModel = AccountViewModel(
            authManager: manager,
            friendService: spy
        )
        viewModel.editingDisplayName = "New Name"

        await viewModel.saveDisplayName()

        #expect(spy.propagatedName == nil)
    }

    @Test("Sign out delegates to auth manager")
    func signOutDelegatesToAuthManager() async {
        let manager = await makeSignedInManager()
        let viewModel = AccountViewModel(authManager: manager)

        await viewModel.signOut()

        #expect(manager.authState == .signedOut)
        #expect(manager.currentUser == nil)
    }

    @Test("Delete account delegates to auth manager")
    func deleteAccountDelegatesToAuthManager() async {
        let manager = await makeSignedInManager()
        let viewModel = AccountViewModel(authManager: manager)

        await viewModel.deleteAccount()

        #expect(manager.authState == .signedOut)
        #expect(manager.currentUser == nil)
    }
}

// MARK: - Test Helpers

/// Spy that records whether `propagateDisplayName` was called and with what value.
@MainActor
private final class SpyFriendService: FriendService {
    private(set) var propagatedName: String?

    nonisolated func propagateDisplayName(_ newName: String) async throws {
        await MainActor.run { propagatedName = newName }
    }

    nonisolated func sendFriendRequest(toUsername username: String) async throws {}
    nonisolated func acceptFriendRequest(_ requestID: String) async throws {}
    nonisolated func declineFriendRequest(_ requestID: String) async throws {}
    nonisolated func removeFriend(_ friendUID: String) async throws {}
    nonisolated func friends() async throws -> [FriendProfile] { [] }
    nonisolated func incomingRequestsStream() -> AsyncStream<[FriendRequest]> {
        AsyncStream { $0.finish() }
    }
    nonisolated func friendsStream() -> AsyncStream<[FriendProfile]> {
        AsyncStream { $0.finish() }
    }
    nonisolated func claimUsername(_ username: String) async throws -> Bool { true }
    nonisolated func isUsernameAvailable(_ username: String) async throws -> Bool { true }
    nonisolated func currentUsername() async throws -> String? { nil }
    nonisolated func searchByUsername(_ username: String) async throws -> UserSearchResult? { nil }
    nonisolated func reportFocusSession(minutes: Int) async throws {}
    nonisolated func leaderboardEntries() async throws -> [LeaderboardEntry] { [] }
    nonisolated func deleteAccountData() async throws {}
}
