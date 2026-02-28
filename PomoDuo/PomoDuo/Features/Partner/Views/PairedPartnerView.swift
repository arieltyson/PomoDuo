import SwiftData
import SwiftUI

/// Screen shown once a partner has connected successfully.
///
/// Paired sessions use the user's saved ``TimerConfiguration`` so timer
/// behavior stays consistent between solo and paired workflows.
struct PairedPartnerView: View {
    let partner: PartnerProfile
    let sessionViewModel: PartnerSessionViewModel
    let onUnpair: () -> Void

    @Query private var configurations: [TimerConfiguration]
    @State private var showUnpairConfirmation = false

    private var activeConfiguration: TimerConfiguration? {
        configurations.first
    }

    private var focusDuration: TimeInterval {
        activeConfiguration?.focusDuration ?? 25 * 60
    }

    private var totalRounds: Int {
        activeConfiguration?.roundsBeforeLongBreak ?? 4
    }

    private var pairedAtDescription: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        let relativeText = formatter.localizedString(
            for: partner.pairedAt,
            relativeTo: .now
        )
        return "Paired \(relativeText)"
    }

    var body: some View {
        VStack {
            Spacer()

            PartnerAvatar(name: partner.displayName)

            Text(partner.displayName)
                .font(.title2)
                .bold()

            Text(pairedAtDescription)
            .font(.subheadline)
            .foregroundStyle(.secondary)

            SessionConfigurationSummary(
                focusDuration: focusDuration,
                totalRounds: totalRounds
            )
            .padding(.top)

            Spacer()

            VStack {
                Button("Start Session", systemImage: "play.fill") {
                    Task {
                        await sessionViewModel.startSession(
                            with: partner,
                            duration: focusDuration,
                            totalRounds: totalRounds
                        )
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

/// Shows the active paired-session timer settings before the session starts.
private struct SessionConfigurationSummary: View {
    let focusDuration: TimeInterval
    let totalRounds: Int

    var body: some View {
        HStack {
            Label("\(Int(focusDuration / 60)) min focus", systemImage: "timer")

            Text("·")
                .foregroundStyle(.tertiary)

            Label(
                "\(totalRounds) rounds",
                systemImage: "arrow.trianglehead.2.clockwise"
            )
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
}
