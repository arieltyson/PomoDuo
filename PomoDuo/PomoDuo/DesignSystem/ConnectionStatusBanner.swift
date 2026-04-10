import SwiftUI

/// Compact status capsule shown when the device goes offline or reconnects.
///
/// Presents two states:
/// - **Offline** — a persistent amber-tinted material capsule indicating
///   partner sync is paused.
/// - **Reconnected** — a brief success capsule confirming sync has resumed,
///   which auto-dismisses after a short delay.
///
/// Fires `.sensoryFeedback` on both transitions so the user has a tactile
/// signal even without looking at the screen (Apple HIG: Haptics should
/// complement visual feedback, not replace it).
struct ConnectionStatusBanner: View {
    @Environment(ConnectionMonitor.self) private var connectionMonitor

    /// Tracks the visible banner phase so reconnection can linger briefly.
    @State private var phase = BannerPhase.hidden

    /// Monotonic counter that increments on each transition, driving
    /// `.sensoryFeedback` even when the same phase repeats.
    @State private var hapticTrigger = 0

    var body: some View {
        Group {
            switch phase {
            case .hidden:
                EmptyView()

            case .offline:
                StatusCapsule(
                    icon: "wifi.slash",
                    message: "Offline — partner sync paused",
                    iconStyle: AppColors.pauseTint,
                    accessibilityMessage: "Offline, partner sync paused"
                )

            case .reconnected:
                StatusCapsule(
                    icon: "wifi",
                    message: "Back online — syncing",
                    iconStyle: AppColors.success,
                    accessibilityMessage: "Back online, partner sync resumed"
                )
            }
        }
        .sensoryFeedback(phase.feedback, trigger: hapticTrigger)
        .onChange(of: connectionMonitor.isConnected) { wasConnected, isConnected in
            if !isConnected {
                withAnimation(.smooth) {
                    phase = .offline
                }
                hapticTrigger += 1
            } else if wasConnected == false {
                // Just reconnected — show brief confirmation.
                withAnimation(.smooth) {
                    phase = .reconnected
                }
                hapticTrigger += 1
                scheduleAutoDismiss()
            }
        }
        .task {
            // Sync initial state without haptic (app just appeared).
            if !connectionMonitor.isConnected {
                phase = .offline
            }
        }
    }

    /// Dismisses the reconnected capsule after a brief delay, giving the
    /// user enough time to read the confirmation without it being permanent.
    private func scheduleAutoDismiss() {
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            guard phase == .reconnected else { return }
            withAnimation(.smooth) {
                phase = .hidden
            }
        }
    }
}

// MARK: - Banner Phase

private enum BannerPhase: Equatable {
    case hidden
    case offline
    case reconnected

    /// Sensory feedback appropriate for each transition.
    var feedback: SensoryFeedback {
        switch self {
        case .hidden:
            .impact(weight: .light)
        case .offline:
            .impact(weight: .light, intensity: 0.6)
        case .reconnected:
            .impact(flexibility: .soft, intensity: 0.4)
        }
    }
}

// MARK: - Status Capsule

/// Reusable capsule view for both offline and reconnected states.
///
/// Keeps the layout identical between phases so the transition animates
/// smoothly without geometry jumps.
private struct StatusCapsule<S: ShapeStyle>: View {
    let icon: String
    let message: String
    let iconStyle: S
    let accessibilityMessage: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(iconStyle)

            Text(message)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 14)
        .background(.ultraThinMaterial, in: .capsule)
        .transition(.move(edge: .top).combined(with: .opacity))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
        .accessibilityLabel(accessibilityMessage)
    }
}
