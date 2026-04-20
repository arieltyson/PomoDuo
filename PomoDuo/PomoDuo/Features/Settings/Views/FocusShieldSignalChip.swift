import SwiftUI

/// A compact icon-over-label signal displayed beneath the Focus Shield
/// emblem. Signals describe how blocking works, never its runtime state.
struct FocusShieldSignalChip: View {
    let title: LocalizedStringKey
    let systemImage: String

    private enum Metrics {
        static let glyphFrame: CGFloat = 32
        static let tintOpacity: Double = 0.14
        static let stackSpacing: CGFloat = 6
    }

    var body: some View {
        VStack(spacing: Metrics.stackSpacing) {
            Image(systemName: systemImage)
                .font(.system(.footnote, design: .rounded).weight(.semibold))
                .foregroundStyle(AppColors.lavender)
                .frame(width: Metrics.glyphFrame, height: Metrics.glyphFrame)
                .background(
                    AppColors.lavender.opacity(Metrics.tintOpacity),
                    in: .circle
                )
                .accessibilityHidden(true)

            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(AppColors.secondaryLabel)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}
