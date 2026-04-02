import SwiftUI

struct DisplayNameSection: View {
    @Bindable var viewModel: AccountViewModel
    @FocusState private var isDisplayNameFocused: Bool

    var body: some View {
        Section("Display Name") {
            AccountSettingsCard {
                TextField(
                    "Name shown to your partner",
                    text: $viewModel.editingDisplayName
                )
                .textContentType(.name)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .focused($isDisplayNameFocused)
                .disabled(viewModel.isSaving)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    AppColors.surfaceSecondary.opacity(0.8),
                    in: .rect(cornerRadius: 14)
                )
                .accessibilityHint("Name shown to your study partner.")
                .onSubmit {
                    saveDisplayName()
                }

                if let validationError = viewModel.nameValidationError {
                    Text(validationError)
                        .font(.caption)
                        .foregroundStyle(AppColors.stopTint)
                } else {
                    Text("This name is visible to your partner during paired sessions.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if viewModel.hasNameChanges {
                    DisplayNameActionGroup(
                        viewModel: viewModel,
                        onSave: saveDisplayName
                    )
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.hasNameChanges)
        .animation(
            .easeInOut(duration: 0.2),
            value: viewModel.nameValidationError
        )
    }

    private func saveDisplayName() {
        guard !viewModel.isSaving else { return }

        Task {
            await viewModel.saveDisplayName()
            isDisplayNameFocused = false
        }
    }
}
