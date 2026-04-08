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

        // Use the current display name if available; fall back to empty
        // string rather than a placeholder like "Focus Friend" to avoid
        // persisting a meaningless default.
        let currentName = authManager.currentUser?.displayName ?? ""
        self.editingDisplayName = currentName == "Focus Friend" ? "" : currentName
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

        // After the async call, check whether the update succeeded by
        // reading the freshly refreshed auth state.
        if authManager.authError == nil {
            // Update succeeded — sync the text field with the confirmed name.
            editingDisplayName = authManager.currentUser?.displayName ?? trimmedName

            // Propagate to Firestore profile and all denormalized friendship/
            // partnership documents so existing friends see the new name.
            try? await friendService?.propagateDisplayName(trimmedName)
        }
        // On failure the authError alert will fire; keep the user's typed
        // text so they can retry without retyping.
    }

    /// Restores the display name draft from the current signed-in identity.
    func resetDisplayName() {
        let currentName = authManager.currentUser?.displayName ?? ""
        editingDisplayName = currentName == "Focus Friend" ? "" : currentName
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

    /// Deletes the current account permanently, including all server-side data.
    func deleteAccount() async {
        try? await friendService?.deleteAccountData()
        await authManager.deleteAccount()
    }
}
