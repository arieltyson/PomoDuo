//
//  AccountView.swift
//  PomoDuo
//
//  Created by Codex on 2/16/26.
//

import SwiftUI

/// Detail screen for account profile and identity actions.
struct AccountView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: AccountViewModel

    init(authManager: AuthManager) {
        _viewModel = State(initialValue: AccountViewModel(authManager: authManager))
    }

    var body: some View {
        Form {
            if let user = viewModel.authManager.currentUser {
                Section {
                    VStack {
                        Image(systemName: user.isAnonymous ? "person.crop.circle.dashed" : "person.crop.circle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(user.isAnonymous ? .secondary : AppColors.lavender)
                            .accessibilityHidden(true)

                        Text(user.displayName)
                            .font(.title3)
                            .bold()

                        Text(user.isAnonymous ? "Guest Account" : "Signed In")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }

                Section("Display Name") {
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

                            Spacer()

                            Button("Save", systemImage: "checkmark") {
                                Task {
                                    await viewModel.saveDisplayName()
                                }
                            }
                            .disabled(viewModel.nameValidationError != nil || viewModel.isSaving)
                        }
                    }
                } footer: {
                    Text("This name is visible to your partner during paired sessions.")
                }

                Section("Account") {
                    LabeledContent("Type") {
                        Text(user.isAnonymous ? "Guest" : "Email")
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

                Section {
                    Button("Sign Out", systemImage: "rectangle.portrait.and.arrow.right") {
                        Task {
                            await viewModel.signOut()
                            dismiss()
                        }
                    }
                    .disabled(viewModel.isSaving)
                }

                Section {
                    Button("Delete Account", systemImage: "trash", role: .destructive) {
                        viewModel.isShowingDeleteConfirmation = true
                    }
                    .disabled(viewModel.isSaving)
                } footer: {
                    Text("Deleting your account removes your profile identity from this device.")
                }
            } else {
                Section {
                    ContentUnavailableView {
                        Label("No Account", systemImage: "person.crop.circle.badge.xmark")
                    } description: {
                        Text("Sign in to manage your account details.")
                    }
                }
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
