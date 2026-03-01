import SwiftUI

/// Detail screen for account profile and identity actions.
struct AccountView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: AccountViewModel

    init(authManager: AuthManager) {
        _viewModel = State(
            initialValue: AccountViewModel(authManager: authManager)
        )
    }

    var body: some View {
        Form {
            if let user = viewModel.authManager.currentUser {
                AccountHeaderSection(user: user)

                if viewModel.canUpgradeToApple {
                    AppleIDUpgradeSection(viewModel: viewModel)
                }

                DisplayNameSection(viewModel: viewModel)
                AccountInfoSection(user: user, viewModel: viewModel)
                SignOutSection(viewModel: viewModel, dismiss: dismiss)
                DeleteAccountSection(viewModel: viewModel)
            } else {
                SignedOutSection()
            }
        }
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Account Error", isPresented: authErrorIsPresented) {
            Button("OK") {
                viewModel.authManager.clearError()
            }
        } message: {
            if let authError = viewModel.authManager.authError {
                Text(authError)
            }
        }
        .confirmationDialog(
            "Delete Account",
            isPresented: $viewModel.isShowingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Account", role: .destructive) {
                Task {
                    await viewModel.deleteAccount()
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
    }

    private var authErrorIsPresented: Binding<Bool> {
        Binding(
            get: { viewModel.authManager.authError != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.authManager.clearError()
                }
            }
        )
    }
}

private struct AccountHeaderSection: View {
    let user: AuthUser

    var body: some View {
        Section {
            VStack {
                AccountAvatar(user: user)

                Text(user.displayName)
                    .font(.title3)
                    .bold()
                    .accessibilityAddTraits(.isHeader)

                AccountTypeBadge(user: user)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "\(user.displayName), \(user.isAnonymous ? "Guest Account" : "Apple ID")"
            )
        }
    }
}

private struct AccountAvatar: View {
    let user: AuthUser

    var body: some View {
        Image(systemName: avatarSymbol)
            .font(.largeTitle)
            .foregroundStyle(avatarColor)
            .accessibilityHidden(true)
    }

    private var avatarSymbol: String {
        switch user.authProvider {
        case .anonymous:
            "person.crop.circle.dashed"
        case .apple:
            "person.crop.circle.fill.badge.checkmark"
        case .email:
            "person.crop.circle.fill"
        }
    }

    private var avatarColor: Color {
        user.isAnonymous ? .secondary : AppColors.lavender
    }
}

private struct AccountTypeBadge: View {
    let user: AuthUser

    var body: some View {
        HStack {
            if user.authProvider == .apple {
                Image(systemName: "apple.logo")
                    .font(.caption2)
            }

            Text(badgeText)
                .font(.caption)
        }
        .foregroundStyle(badgeColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(badgeColor.opacity(0.12), in: .capsule)
    }

    private var badgeText: String {
        switch user.authProvider {
        case .anonymous:
            "Guest Account"
        case .apple:
            "Apple ID"
        case .email:
            "Email Account"
        }
    }

    private var badgeColor: Color {
        user.isAnonymous ? .secondary : AppColors.lavender
    }
}

private struct AppleIDUpgradeSection: View {
    let viewModel: AccountViewModel

    var body: some View {
        Section {
            AppleIDUpgradePromptView {
                Task {
                    await viewModel.linkWithApple()
                }
            }
            .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
        } footer: {
            Text(
                "Your existing partnerships, session history, and stats are preserved when you link your Apple ID."
            )
        }
    }
}

private struct DisplayNameSection: View {
    @Bindable var viewModel: AccountViewModel

    var body: some View {
        Section {
            TextField("Display Name", text: $viewModel.editingDisplayName)
                .textContentType(.name)
                .autocorrectionDisabled()
                .accessibilityHint("Name shown to your study partner.")

            if let validationError = viewModel.nameValidationError {
                Text(validationError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if viewModel.hasNameChanges {
                HStack {
                    Button("Revert", role: .cancel) {
                        viewModel.resetDisplayName()
                    }
                    .accessibilityHint("Discards display name changes.")

                    Spacer()

                    Button("Save", systemImage: "checkmark") {
                        Task {
                            await viewModel.saveDisplayName()
                        }
                    }
                    .disabled(
                        viewModel.nameValidationError != nil
                            || viewModel.isSaving
                    )
                    .accessibilityHint("Saves the new display name.")
                }
            }
        } header: {
            Text("Display Name")
        } footer: {
            Text(
                "This name is visible to your partner during paired sessions."
            )
        }
    }
}

private struct AccountInfoSection: View {
    let user: AuthUser
    let viewModel: AccountViewModel

    var body: some View {
        Section("Account") {
            LabeledContent("Type") {
                Text(viewModel.accountTypeLabel)
            }

            if let email = user.email {
                LabeledContent("Email") {
                    Text(email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            LabeledContent("User ID") {
                Text(String(user.id.prefix(12)))
                    .font(.caption)
                    .monospaced()
                    .foregroundStyle(.secondary)
            }

            LabeledContent("Created") {
                Text(user.createdAt, style: .date)
            }
        }
    }
}

private struct SignOutSection: View {
    let viewModel: AccountViewModel
    let dismiss: DismissAction

    var body: some View {
        Section {
            Button("Sign Out", systemImage: "rectangle.portrait.and.arrow.right") {
                Task {
                    await viewModel.signOut()
                    dismiss()
                }
            }
            .disabled(viewModel.isSaving)
            .accessibilityHint("Signs out and returns to anonymous mode.")
        }
    }
}

private struct DeleteAccountSection: View {
    @Bindable var viewModel: AccountViewModel

    var body: some View {
        Section {
            Button("Delete Account", systemImage: "trash", role: .destructive) {
                viewModel.isShowingDeleteConfirmation = true
            }
            .disabled(viewModel.isSaving)
            .accessibilityHint(
                "Permanently deletes your profile, partnerships, and session history."
            )
        } footer: {
            Text(
                "Deleting your account removes your profile, partnerships, and session history permanently."
            )
        }
    }
}

private struct SignedOutSection: View {
    var body: some View {
        Section {
            ContentUnavailableView {
                Label("No Account", systemImage: "person.crop.circle.badge.xmark")
            } description: {
                Text("Sign in to manage your account details.")
            }
        }
    }
}
