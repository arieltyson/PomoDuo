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
