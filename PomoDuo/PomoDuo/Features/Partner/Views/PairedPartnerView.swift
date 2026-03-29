import SwiftData
import SwiftUI

/// Screen shown once a partner has connected successfully.
///
/// Paired sessions use the user's saved ``TimerConfiguration`` so timer
/// behavior stays consistent between solo and paired workflows.
struct PairedPartnerView: View {
    let partner: PartnerProfile
    @Bindable var sessionViewModel: PartnerSessionViewModel
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

    private var shortBreakDuration: TimeInterval {
        activeConfiguration?.shortBreakDuration ?? 5 * 60
    }

    private var longBreakDuration: TimeInterval {
        activeConfiguration?.longBreakDuration ?? 15 * 60
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
                .accessibilityAddTraits(.isHeader)

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
                            shortBreakDuration: shortBreakDuration,
                            longBreakDuration: longBreakDuration,
                            totalRounds: totalRounds
                        )
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.lavender)
                .disabled(sessionViewModel.isStartingSession)
                .accessibilityHint(
                    "Sends a session request to \(partner.displayName)."
                )
                .accessibilityInputLabels(["Start Session", "Start", "Begin"])

                Button(
                    "Disconnect",
                    systemImage: "person.badge.minus",
                    role: .destructive
                ) {
                    showUnpairConfirmation = true
                }
                .buttonStyle(.bordered)
                .accessibilityHint(
                    "Unpairs from \(partner.displayName). You can reconnect later."
                )
                .accessibilityInputLabels(["Disconnect", "Unpair", "Remove"])
            }
            .controlSize(.large)
            .padding(.bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .alert(
            "Solo Session Active",
            isPresented: $sessionViewModel.isShowingSoloSessionConflict
        ) {
            Button("OK") {}
        } message: {
            Text("You have a focus session running on the Timer tab. Stop it before starting a paired session.")
        }
        .overlay {
            if showUnpairConfirmation {
                DisconnectConfirmationOverlay(
                    partnerName: partner.displayName,
                    isPresented: $showUnpairConfirmation,
                    onConfirm: onUnpair
                )
            }
        }
    }
}

/// Centered modal overlay confirming partner disconnection.
private struct DisconnectConfirmationOverlay: View {
    let partnerName: String
    @Binding var isPresented: Bool
    let onConfirm: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false

    var body: some View {
        ZStack {
            Button {
                dismiss()
            } label: {
                Color.black.opacity(isVisible ? 0.5 : 0)
                    .ignoresSafeArea()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
            .accessibilityAddTraits(.isButton)

            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text("Disconnect from \(partnerName)?")
                        .font(.headline)

                    Text("You can reconnect later using a new pairing code or add them as a friend.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 10) {
                    Button(role: .destructive) {
                        dismiss()
                        onConfirm()
                    } label: {
                        Text("Disconnect")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .controlSize(.large)

                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
            .padding(24)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 20))
            .padding(.horizontal, 40)
            .scaleEffect(isVisible ? 1 : 0.9)
            .opacity(isVisible ? 1 : 0)
        }
        .task {
            withAnimation(reduceMotion ? .none : .spring(duration: 0.3, bounce: 0.15)) {
                isVisible = true
            }
        }
        .accessibilityAddTraits(.isModal)
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.2)) {
            isVisible = false
        }
        Task {
            try? await Task.sleep(for: .milliseconds(200))
            isPresented = false
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
                .accessibilityHidden(true)

            Label(
                "\(totalRounds) rounds",
                systemImage: "arrow.trianglehead.2.clockwise"
            )
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(Int(focusDuration / 60)) minute focus, \(totalRounds) rounds"
        )
    }
}
