import SwiftUI

/// Prompts the user to claim a unique username for friend discovery.
struct UsernameSetupView: View {
    let viewModel: FriendsViewModel
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            UsernameSetupHeader()

            UsernameInputField(viewModel: viewModel)

            UsernameAvailabilityIndicator(viewModel: viewModel)

            Spacer()

            Button {
                Task {
                    await viewModel.claimUsername()
                    if !viewModel.needsUsernameSetup {
                        onComplete()
                    }
                }
            } label: {
                HStack {
                    if viewModel.isClaimingUsername {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(viewModel.isClaimingUsername ? "Claiming…" : "Claim Username")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColors.lavender)
            .controlSize(.large)
            .disabled(!canClaim)
            .padding(.bottom)
        }
        .padding(.horizontal)
        .navigationTitle("Choose a Username")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var canClaim: Bool {
        viewModel.usernameValidation == .valid
            && viewModel.isUsernameAvailable == true
            && !viewModel.isClaimingUsername
    }
}

private struct UsernameSetupHeader: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "at")
                .font(.largeTitle)
                .foregroundStyle(AppColors.lavender)
                .padding()
                .background(
                    AppColors.paleViolet.opacity(0.25),
                    in: .circle
                )

            Text("Pick a Username")
                .font(.title2)
                .bold()

            Text("Your friends will find you by this username. Choose wisely — it cannot be changed later.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct UsernameInputField: View {
    @Bindable var viewModel: FriendsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("@")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                TextField("username", text: $viewModel.usernameInput)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: viewModel.usernameInput) { _, _ in
                        viewModel.validateUsername()
                    }
            }
            .padding(12)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))

            if let errorMessage = viewModel.usernameValidation.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.leading, 4)
            }
        }
    }
}

private struct UsernameAvailabilityIndicator: View {
    let viewModel: FriendsViewModel

    var body: some View {
        Group {
            if viewModel.isCheckingAvailability {
                Label("Checking availability…", systemImage: "ellipsis")
                    .foregroundStyle(.secondary)
            } else if viewModel.isUsernameAvailable == true {
                Label("Username is available", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(AppColors.success)
            } else if viewModel.isUsernameAvailable == false {
                Label("Username is taken", systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
            }
        }
        .font(.caption)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isCheckingAvailability)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isUsernameAvailable)
    }
}
