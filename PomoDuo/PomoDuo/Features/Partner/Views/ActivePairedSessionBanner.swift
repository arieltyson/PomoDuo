import SwiftUI

// MARK: - Partner Banner with Live Status

struct PartnerBannerView: View {
    let partner: PartnerProfile
    let isPartnerActive: Bool

    var body: some View {
        HStack {
            PartnerInitialAvatar(name: partner.displayName)

            VStack(alignment: .leading) {
                Text("Studying with")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(partner.displayName)
                    .font(.headline)
            }

            Spacer()

            PartnerPresenceIndicator(isActive: isPartnerActive)
        }
        .padding()
        .background(
            AppColors.paleViolet.opacity(0.14),
            in: .rect(cornerRadius: 14)
        )
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Studying with \(partner.displayName), \(isPartnerActive ? "active" : "may be offline")"
        )
    }
}

/// Real-time partner presence dot with pulse animation.
///
/// Green pulsing dot when the partner's heartbeat is recent;
/// static orange dot when the partner may be offline.
/// When the Differentiate Without Color setting is on, the offline
/// dot gains a "!" mark so its state is conveyed by shape, not color.
private struct PartnerPresenceIndicator: View {
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityDifferentiateWithoutColor)
    private var differentiateWithoutColor
    @Environment(PowerStateMonitor.self) private var powerStateMonitor

    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(isActive ? .green : .orange)
                    .frame(width: 10, height: 10)

                if !isActive && differentiateWithoutColor {
                    Text("!")
                        .font(.system(size: 7, weight: .black))
                        .foregroundStyle(.white)
                }
            }
            .overlay {
                if isActive
                    && !reduceMotion
                    && !powerStateMonitor.isLowPowerModeEnabled
                {
                    PulsingRing()
                }
            }

            Text(isActive ? "Active" : "Offline?")
                .font(.caption2)
                .foregroundStyle(isActive ? .green : .orange)
        }
        .animation(.easeInOut(duration: 0.4), value: isActive)
    }
}

/// Subtle repeating pulse ring that radiates outward from the
/// presence dot while the partner is active.
private struct PulsingRing: View {
    @State private var isPulsing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(PowerStateMonitor.self) private var powerStateMonitor

    var body: some View {
        Circle()
            .stroke(Color.green.opacity(0.4), lineWidth: 2)
            .frame(width: 18, height: 18)
            .scaleEffect(isPulsing ? 1.3 : 1.0)
            .opacity(isPulsing ? 0.0 : 0.6)
            .task(
                id: AnimationTaskID(
                    reduceMotion: reduceMotion,
                    isLowPowerModeEnabled: powerStateMonitor.isLowPowerModeEnabled
                )
            ) {
                guard !reduceMotion, !powerStateMonitor.isLowPowerModeEnabled else {
                    isPulsing = false
                    return
                }
                withAnimation(
                    .easeInOut(duration: 1.5)
                        .repeatForever(autoreverses: false)
                ) {
                    isPulsing = true
                }
            }
    }

    private struct AnimationTaskID: Equatable {
        let reduceMotion: Bool
        let isLowPowerModeEnabled: Bool
    }
}

/// Honest active-session blocking chip for paired focus.
///
/// Mirrors the solo timer's chip semantics: copy reflects what the app
/// honestly knows ("blocking requested" / "repairing"), never the
/// stronger "Apps Blocked" claim about OS-level enforcement that Apple
/// does not expose.
struct PairedBlockingIndicatorView: View {
    let health: ScreenTimeRuntimeHealth

    var body: some View {
        Group {
            switch health {
            case .healthy:
                Label("Blocking Active", systemImage: "shield.fill")
                    .accessibilityLabel(
                        "App blocking active for this focus session."
                    )
            case .degraded:
                Label(
                    "Blocking · Repairing",
                    systemImage: "exclamationmark.shield.fill"
                )
                .accessibilityLabel(
                    "App blocking is being repaired for this focus session."
                )
            case .unavailable:
                EmptyView()
            }
        }
        .font(.caption2)
        .foregroundStyle(AppColors.lavender)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(AppColors.lavender.opacity(0.14), in: .capsule)
        .transition(.opacity)
    }
}

private struct PartnerInitialAvatar: View {
    let name: String

    var body: some View {
        Text(initial)
            .font(.title3)
            .bold()
            .foregroundStyle(.white)
            .frame(width: 40, height: 40)
            .background(
                LinearGradient(
                    colors: [AppColors.lavender, AppColors.lilac],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: .circle
            )
            .accessibilityHidden(true)
    }

    private var initial: String {
        name.first.map(String.init) ?? "?"
    }
}
