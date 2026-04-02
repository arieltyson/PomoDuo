import SwiftUI

struct DisplayNameActionGroup: View {
    @Bindable var viewModel: AccountViewModel
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: onSave) {
                HStack(spacing: 8) {
                    if viewModel.isSaving {
                        ProgressView()
                            .controlSize(.small)
                    }

                    Text(viewModel.isSaving ? "Saving…" : "Save Changes")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColors.lavender)
            .controlSize(.large)
            .disabled(
                viewModel.isSaving || viewModel.nameValidationError != nil
            )
            .accessibilityHint("Saves the new display name.")

            Button("Revert", role: .cancel) {
                viewModel.resetDisplayName()
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .disabled(viewModel.isSaving)
            .accessibilityHint("Discards display name changes.")
        }
    }
}
