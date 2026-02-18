import SwiftUI

/// Screen displayed while waiting for a partner to join a generated code.
struct WaitingForPartnerView: View {
    let code: PairCode
    let onCancel: () -> Void

    var body: some View {
        VStack {
            Spacer()

            ProgressView()
                .controlSize(.large)
                .tint(AppColors.lavender)

            Text("Waiting for Partner")
                .font(.title2)
                .bold()

            Text("Share this code with your partner:")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            PairingCodeCard(code: code)

            Text("They can enter it in PomoDuo to connect with you.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            Button("Cancel", role: .cancel, action: onCancel)
                .buttonStyle(.bordered)
                .controlSize(.large)
                .padding(.bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct PairingCodeCard: View {
    let code: PairCode

    var body: some View {
        VStack {
            Text(code.displayValue)
                .font(.largeTitle)
                .monospaced()
                .bold()
                .foregroundStyle(AppColors.lavender)

            ShareLink("Share Code", item: code.value)
                .font(.caption)
                .tint(AppColors.lilac)
        }
        .padding()
        .background(AppColors.paleViolet.opacity(0.2))
        .clipShape(.rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Pairing code \(code.value.map(String.init).joined(separator: " "))"
        )
    }
}
