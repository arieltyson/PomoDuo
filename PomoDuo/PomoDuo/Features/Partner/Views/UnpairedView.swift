import SwiftUI

/// Initial partner state when no one is paired yet.
struct UnpairedView: View {
    let onGenerateCode: () -> Void
    let onEnterCode: () -> Void

    var body: some View {
        VStack {
            Spacer()

            PairingIllustrationView()

            Text("Study Better Together")
                .font(.title2)
                .bold()

            Text(
                "Pair with your study partner for shared focus sessions and accountability."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal)

            Spacer()

            VStack {
                Button(
                    "Generate Pairing Code",
                    systemImage: "qrcode",
                    action: onGenerateCode
                )
                .buttonStyle(.borderedProminent)
                .tint(AppColors.lavender)

                Button(
                    "Enter Partner's Code",
                    systemImage: "keyboard",
                    action: onEnterCode
                )
                .buttonStyle(.bordered)
                .tint(AppColors.lavender)
            }
            .controlSize(.large)
            .padding(.bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct PairingIllustrationView: View {
    var body: some View {
        Image(systemName: "person.2.fill")
            .font(.largeTitle)
            .foregroundStyle(AppColors.lavender)
            .padding()
            .background(AppColors.paleViolet.opacity(0.25), in: .circle)
            .accessibilityHidden(true)
    }
}
