import SwiftUI

/// Premium hero for the App Blocking settings screen.
///
/// Anchors the screen with a layered shield emblem, a single supportive
/// line, and three honest signal chips. The chips describe *how* blocking
/// works — they never claim current runtime state.
struct FocusShieldHeroCard: View {
    private enum Metrics {
        static let cornerRadius: CGFloat = 24
        static let verticalPadding: CGFloat = 24
        static let horizontalPadding: CGFloat = 20
        static let outerSpacing: CGFloat = 20
        static let titleStackSpacing: CGFloat = 4
        static let chipsSpacing: CGFloat = 12
        static let chipsTopPadding: CGFloat = 4
        static let strokeOpacity: Double = 0.14
    }

    var body: some View {
        VStack(spacing: Metrics.outerSpacing) {
            FocusShieldEmblem()

            VStack(spacing: Metrics.titleStackSpacing) {
                Text("Focus Shield")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)

                Text("Your focus, gently protected.")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.secondaryLabel)
                    .multilineTextAlignment(.center)
            }

            HStack(alignment: .top, spacing: Metrics.chipsSpacing) {
                FocusShieldSignalChip(
                    title: "Screen Time",
                    systemImage: "lock.shield.fill"
                )
                FocusShieldSignalChip(
                    title: "Session Only",
                    systemImage: "timer"
                )
                FocusShieldSignalChip(
                    title: "On-Device",
                    systemImage: "iphone"
                )
            }
            .padding(.top, Metrics.chipsTopPadding)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Metrics.verticalPadding)
        .padding(.horizontal, Metrics.horizontalPadding)
        .background(
            .ultraThinMaterial,
            in: .rect(cornerRadius: Metrics.cornerRadius)
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: Metrics.cornerRadius,
                style: .continuous
            )
            .strokeBorder(
                AppColors.lavender.opacity(Metrics.strokeOpacity),
                lineWidth: 1
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Focus Shield. Your focus, gently protected.")
        .accessibilityValue(
            "Powered by Screen Time, active during focus sessions, processed on device."
        )
    }
}
