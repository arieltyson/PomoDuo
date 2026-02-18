import SwiftUI

/// Screen shown once a partner has connected successfully.
struct PairedPartnerView: View {
    let partner: PartnerProfile
    let sessionViewModel: PartnerSessionViewModel
    let onUnpair: () -> Void

    @State private var showUnpairConfirmation = false

    var body: some View {
        VStack {
            Spacer()

            PartnerAvatar(name: partner.displayName)

            Text(partner.displayName)
                .font(.title2)
                .bold()

            Text(
                "Paired \(partner.pairedAt, format: .relative(presentation: .named))"
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)

            Spacer()

            VStack {
                Button("Start Session", systemImage: "play.fill") {
                    Task {
                        await sessionViewModel.startSession(with: partner)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.lavender)
                .disabled(sessionViewModel.isStartingSession)

                Button(
                    "Disconnect",
                    systemImage: "person.badge.minus",
                    role: .destructive
                ) {
                    showUnpairConfirmation = true
                }
                .buttonStyle(.bordered)
            }
            .controlSize(.large)
            .padding(.bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .confirmationDialog(
            "Disconnect from \(partner.displayName)?",
            isPresented: $showUnpairConfirmation,
            titleVisibility: .visible
        ) {
            Button("Disconnect", role: .destructive, action: onUnpair)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You can reconnect later using a new pairing code.")
        }
    }
}

private struct PartnerAvatar: View {
    let name: String

    private var initial: String {
        name.first.map(String.init) ?? "?"
    }

    var body: some View {
        Text(initial)
            .font(.largeTitle)
            .bold()
            .foregroundStyle(.white)
            .frame(width: 96, height: 96)
            .background(
                LinearGradient(
                    colors: [AppColors.lavender, AppColors.lilac],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: .circle
            )
            .accessibilityLabel("Partner avatar for \(name)")
    }
}
