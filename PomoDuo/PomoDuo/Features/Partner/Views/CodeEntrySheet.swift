import SwiftUI

/// Modal sheet used to enter a partner's pairing code.
struct CodeEntrySheet: View {
    @Bindable var viewModel: PairingViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                Spacer()

                Image(systemName: "link.badge.plus")
                    .font(.largeTitle)
                    .foregroundStyle(AppColors.lavender)
                    .accessibilityHidden(true)

                Text("Enter Partner's Code")
                    .font(.title2)
                    .bold()

                Text("Ask your partner for their 6-character code.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                PairingCodeTextField(
                    codeInput: $viewModel.codeInput,
                    isInvalid: viewModel.codeInputIsInvalid
                )

                if viewModel.codeInputIsInvalid {
                    Text("Please enter a valid 6-character code.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Spacer()

                Button("Connect", systemImage: "link") {
                    Task {
                        await viewModel.joinWithEnteredCode()
                        if case .paired = viewModel.pairingState {
                            dismiss()
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.lavender)
                .controlSize(.large)
                .disabled(viewModel.codeInput.count < PairCode.length)
                .padding(.bottom)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Join Partner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct PairingCodeTextField: View {
    @Binding var codeInput: String
    let isInvalid: Bool

    var body: some View {
        TextField("ABC123", text: $codeInput)
            .font(.title)
            .monospaced()
            .multilineTextAlignment(.center)
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
            .padding()
            .background(
                .clear,
                in: .rect(cornerRadius: 12)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isInvalid ? .red : AppColors.lavender.opacity(0.5),
                        lineWidth: 2
                    )
            }
            .padding(.horizontal)
            .onChange(of: codeInput) { _, newValue in
                let normalized = normalize(newValue)
                if normalized != newValue {
                    codeInput = normalized
                }
            }
            .accessibilityLabel("Pairing code")
    }

    private func normalize(_ input: String) -> String {
        let candidate =
            input
            .uppercased()
            .replacing("-", with: "")
            .replacing(" ", with: "")
            .filter { $0.isLetter || $0.isNumber }

        if candidate.count <= PairCode.length {
            return candidate
        }

        return String(candidate.prefix(PairCode.length))
    }
}
