import SwiftUI

/// Shown when the partner initiates a focus session and the current user
/// needs to accept or decline.
///
/// This view replaces ``ActivePairedSessionView`` for the receiving partner
/// while the session is in the `.requesting` state. Once the user taps
/// **Accept**, the session transitions to `.focus` and the standard active
/// session view takes over.
struct IncomingSessionRequestView: View {
    let partner: PartnerProfile
    let viewModel: PartnerSessionViewModel

    @State private var haptic = HapticTrigger()

    var body: some View {
        VStack {
            Spacer()

            IncomingRequestIllustration()

            Text("\(partner.displayName) wants to study!")
                .font(.title2)
                .bold()
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            Text("Accept to start a focus session together.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            IncomingRequestActions(
                viewModel: viewModel,
                partnerName: partner.displayName
            )
            .padding(.bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal)
        .sensoryFeedback(haptic.feedback, trigger: haptic)
        .task {
            haptic.fire(.start)
            AccessibilityAnnouncer.announceIncomingSessionRequest(
                partnerName: partner.displayName
            )
        }
    }
}

// MARK: - Subviews

private struct IncomingRequestIllustration: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            AppColors.lavender.opacity(0.2),
                            AppColors.lilac.opacity(0.15),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 140, height: 140)

            Image(systemName: "person.2.wave.2.fill")
                .font(.largeTitle)
                .foregroundStyle(AppColors.lavender)
                .symbolEffect(.pulse, options: .repeating, isActive: !reduceMotion)
        }
        .padding(.bottom)
        .accessibilityHidden(true)
    }
}

private struct IncomingRequestActions: View {
    let viewModel: PartnerSessionViewModel
    let partnerName: String

    var body: some View {
        VStack {
            Button("Accept", systemImage: "checkmark.circle.fill") {
                Task {
                    await viewModel.acceptIncomingSession()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColors.lavender)
            .accessibilityHint(
                "Starts a focus session with \(partnerName)."
            )

            Button(
                "Decline",
                systemImage: "xmark.circle",
                role: .destructive
            ) {
                Task {
                    await viewModel.declineIncomingSession()
                }
            }
            .buttonStyle(.bordered)
            .accessibilityHint("Declines the session request.")
        }
        .controlSize(.large)
    }
}
