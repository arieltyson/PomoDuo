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
        VStack(spacing: 12) {
            Button("Accept", systemImage: "checkmark.circle.fill") {
                Task {
                    await viewModel.acceptIncomingSession()
                }
            }
            .buttonStyle(SessionActionButtonStyle(tint: AppColors.lavender))
            .accessibilityHint(
                "Starts a focus session with \(partnerName)."
            )
            .accessibilityInputLabels(["Accept", "Yes", "OK"])

            Button(
                "Decline",
                systemImage: "xmark.circle",
                role: .destructive
            ) {
                Task {
                    await viewModel.declineIncomingSession()
                }
            }
            .buttonStyle(SessionActionButtonStyle(tint: AppColors.stopTint))
            .accessibilityHint("Declines the session request.")
            .accessibilityInputLabels(["Decline", "No", "Reject"])
        }
    }
}

/// Glass-material capsule button for session actions.
private struct SessionActionButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body)
            .fontWeight(.semibold)
            .foregroundStyle(tint)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(.thinMaterial, in: .capsule)
            .overlay {
                Capsule()
                    .stroke(tint.opacity(0.36), lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
