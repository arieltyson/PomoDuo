import SwiftUI

/// Decorative layered shield emblem for the App Blocking hero.
///
/// A hierarchical `shield.lefthalf.filled` glyph sits atop two concentric
/// lavender halos and a soft inner disk. When Reduce Motion is off, the
/// outermost halo gently breathes to imply a living, protective aura —
/// never implying current runtime shield state.
struct FocusShieldEmblem: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isBreathing = false

    private enum Metrics {
        static let outerDiameter: CGFloat = 128
        static let middleDiameter: CGFloat = 96
        static let innerDiameter: CGFloat = 72
        static let glyphPointSize: CGFloat = 44
        static let outerHaloOpacity: Double = 0.18
        static let middleHaloOpacity: Double = 0.32
        static let innerDiskOpacity: Double = 0.14
        static let breatheScaleMin: CGFloat = 1.0
        static let breatheScaleMax: CGFloat = 1.04
        static let breatheDuration: TimeInterval = 2.4
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    AppColors.lavender.opacity(Metrics.outerHaloOpacity),
                    lineWidth: 1
                )
                .frame(
                    width: Metrics.outerDiameter,
                    height: Metrics.outerDiameter
                )
                .scaleEffect(
                    isBreathing ? Metrics.breatheScaleMax : Metrics.breatheScaleMin
                )

            Circle()
                .stroke(
                    AppColors.lavender.opacity(Metrics.middleHaloOpacity),
                    lineWidth: 1.5
                )
                .frame(
                    width: Metrics.middleDiameter,
                    height: Metrics.middleDiameter
                )

            Circle()
                .fill(AppColors.lavender.opacity(Metrics.innerDiskOpacity))
                .frame(
                    width: Metrics.innerDiameter,
                    height: Metrics.innerDiameter
                )

            Image(systemName: "shield.lefthalf.filled")
                .font(
                    .system(
                        size: Metrics.glyphPointSize,
                        weight: .semibold,
                        design: .rounded
                    )
                )
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(AppColors.lavender)
        }
        .frame(
            width: Metrics.outerDiameter,
            height: Metrics.outerDiameter
        )
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion, !isBreathing else { return }
            withAnimation(
                .easeInOut(duration: Metrics.breatheDuration)
                    .repeatForever(autoreverses: true)
            ) {
                isBreathing = true
            }
        }
    }
}
