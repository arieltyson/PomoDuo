import SwiftUI

/// Compact focus-session status shown below the timer controls.
struct TimerBlockingStatusChip: View {
    struct Metrics {
        let height: CGFloat
        let spacing: CGFloat
    }

    static let metrics = Metrics(height: 26, spacing: 8)

    let isPresented: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Label("Blocking Active", systemImage: "shield.fill")
            .font(.caption2.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.9)
            .foregroundStyle(AppColors.lavender)
            .padding(.horizontal, 10)
            .frame(height: Self.metrics.height)
            .background(AppColors.lavender.opacity(0.14), in: .capsule)
            .overlay {
                Capsule()
                    .stroke(AppColors.lavender.opacity(0.24), lineWidth: 1)
            }
            .opacity(isPresented ? 1 : 0)
            .scaleEffect(chipScale, anchor: .top)
            .offset(y: verticalOffset)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("App blocking active for this focus session.")
            .accessibilityHidden(!isPresented)
    }

    private var chipScale: CGFloat {
        guard !reduceMotion else { return 1 }
        return isPresented ? 1 : 0.96
    }

    private var verticalOffset: CGFloat {
        guard !reduceMotion else { return 0 }
        return isPresented ? 0 : -4
    }
}
