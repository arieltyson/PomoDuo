import SwiftUI

/// Circular progress component for the active countdown.
struct CircularProgressView: View {
    /// Remaining progress from `1.0` (start) to `0.0` (complete).
    let remainingProgress: Double
    let timeString: String
    let isPaused: Bool
    let isBreak: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let ringLineWidth: CGFloat = 12

    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    AppColors.paleViolet.opacity(0.26),
                    style: StrokeStyle(
                        lineWidth: ringLineWidth,
                        lineCap: .round
                    )
                )

            Circle()
                .trim(from: 0, to: max(0, min(1, remainingProgress)))
                .stroke(
                    style: StrokeStyle(
                        lineWidth: ringLineWidth,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .foregroundStyle(
                    isBreak ? AppGradients.breakRing : AppGradients.focusRing
                )
                .animation(
                    reduceMotion ? .none : .easeInOut(duration: 0.7),
                    value: remainingProgress
                )

            TimerCenterView(
                timeString: timeString,
                isPaused: isPaused
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityValue(timeString)
        .accessibilityAddTraits(.updatesFrequently)
    }

    private var accessibilityDescription: String {
        let timerType = isBreak ? "Break timer" : "Focus timer"

        if isPaused {
            return "\(timerType), paused"
        }

        let percentComplete = Int((1 - remainingProgress) * 100)
        return "\(timerType), \(percentComplete) percent complete"
    }
}

private struct TimerCenterView: View {
    let timeString: String
    let isPaused: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack {
            Text(timeString)
                .font(.system(.largeTitle, design: .rounded))
                .bold()
                .monospacedDigit()
                .contentTransition(reduceMotion ? .identity : .numericText())
                .foregroundStyle(isPaused ? AppColors.secondaryLabel : .primary)

            if isPaused {
                Label("Paused", systemImage: "pause.fill")
                    .font(.caption)
                    .foregroundStyle(AppColors.pauseTint)
                    .transition(reduceMotion ? .opacity : .opacity)
            }
        }
        .animation(
            reduceMotion ? .none : .easeInOut(duration: 0.2),
            value: isPaused
        )
    }
}
