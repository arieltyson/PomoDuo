import Foundation
import Observation

/// View model for account profile management.
@MainActor
@Observable
final class AccountViewModel {
    /// Maximum allowed display name length.
    private static let maximumDisplayNameLength = 30

    /// Editable display name field.
    var editingDisplayName: String

    /// Whether the delete confirmation dialog is visible.
    var isShowingDeleteConfirmation = false

    /// The user's claimed username, fetched from the friend service.
    private(set) var username: String?

    /// Whether the username is currently being fetched.
    private(set) var isFetchingUsername = false

    let authManager: AuthManager
    let friendService: (any FriendService)?

    init(authManager: AuthManager, friendService: (any FriendService)? = nil) {
        self.authManager = authManager
        self.friendService = friendService
        self.editingDisplayName = authManager.currentUser?.displayName ?? ""
    }

    /// Fetches the current user's username from Firestore.
    func fetchUsername() async {
        guard let friendService else { return }
        isFetchingUsername = true
        username = try? await friendService.currentUsername()
        isFetchingUsername = false
    }

    /// Whether account operations are currently in progress.
    var isSaving: Bool {
        authManager.isLoading
    }

    /// Whether there are unsaved edits for the display name.
    var hasNameChanges: Bool {
        guard let user = authManager.currentUser else {
            return false
        }

        let trimmedName = editingDisplayName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        return !trimmedName.isEmpty && trimmedName != user.displayName
    }

    /// Current validation error for display name editing.
    var nameValidationError: String? {
        let trimmedName = editingDisplayName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        if trimmedName.isEmpty && !editingDisplayName.isEmpty {
            return "Display name cannot be blank."
        }

        if trimmedName.count > Self.maximumDisplayNameLength {
            return
                "Display name must be \(Self.maximumDisplayNameLength) characters or fewer."
        }

        return nil
    }

    /// Human-readable account type for display.
    var accountTypeLabel: String {
        guard let user = authManager.currentUser else {
            return "Unknown"
        }

        switch user.authProvider {
        case .anonymous:
            return "Guest"
        case .apple:
            return "Apple ID"
        case .email:
            return "Email"
        }
    }

    /// Whether the current user can upgrade to Apple ID.
    var canUpgradeToApple: Bool {
        authManager.currentUser?.isAnonymous ?? false
    }

    /// Persists the edited display name when valid and changed.
    func saveDisplayName() async {
        guard nameValidationError == nil else {
            return
        }

        let trimmedName = editingDisplayName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmedName.isEmpty else {
            return
        }

        guard trimmedName != authManager.currentUser?.displayName else {
            return
        }

        await authManager.updateDisplayName(trimmedName)
        editingDisplayName = authManager.currentUser?.displayName ?? trimmedName
    }

    /// Restores the display name draft from the current signed-in identity.
    func resetDisplayName() {
        editingDisplayName = authManager.currentUser?.displayName ?? ""
    }

    /// Links the current anonymous account to an Apple ID.
    func linkWithApple() async {
        await authManager.linkWithApple()
    }

    /// Signs in with Apple (replaces current session).
    func signInWithApple() async {
        await authManager.signInWithApple()
    }

    /// Signs out the current account.
    func signOut() async {
        await authManager.signOut()
    }

    /// Deletes the current account permanently.
    func deleteAccount() async {
        await authManager.deleteAccount()
    }
}
