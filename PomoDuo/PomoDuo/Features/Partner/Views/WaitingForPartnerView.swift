import SwiftUI

/// Screen displayed while waiting for a partner to join a generated code.
struct WaitingForPartnerView: View {
    let code: PairCode
    let onCancel: () -> Void

    var body: some View {
        VStack {
            Spacer()

            WaitingHeader()

            PairingCodeCard(code: code)
                .padding(.top, 32)

            Text("They can enter it in PomoDuo to connect with you.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.top)

            Spacer()
            Spacer()

            Button("Cancel", role: .cancel, action: onCancel)
                .buttonStyle(.bordered)
                .controlSize(.large)
                .padding(.bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Subviews

private struct WaitingHeader: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
                .tint(AppColors.lavender)

            Text("Waiting for Partner")
                .font(.title2)
                .bold()

            Text("Share this code with your partner")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

private struct PairingCodeCard: View {
    let code: PairCode

    var body: some View {
        VStack(spacing: 16) {
            Text(code.displayValue)
                .font(.system(.largeTitle, design: .monospaced))
                .bold()
                .foregroundStyle(AppColors.lavender)

            ShareLink("Share Code", item: code.value)
                .font(.subheadline)
                .tint(AppColors.lilac)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 24)
        .background(AppColors.paleViolet.opacity(0.15))
        .clipShape(.rect(cornerRadius: 20))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Pairing code \(code.value.map(String.init).joined(separator: " "))"
        )
    }
}
