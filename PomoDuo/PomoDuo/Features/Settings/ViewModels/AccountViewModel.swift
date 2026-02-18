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

    let authManager: AuthManager

    init(authManager: AuthManager) {
        self.authManager = authManager
        self.editingDisplayName = authManager.currentUser?.displayName ?? ""
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

    /// Signs out the current account.
    func signOut() async {
        await authManager.signOut()
    }

    /// Deletes the current account permanently.
    func deleteAccount() async {
        await authManager.deleteAccount()
    }
}
