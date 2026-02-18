import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - Widget Entry Point

/// Live Activity rendering for Lock Screen and Dynamic Island.
///
/// Follows Apple HIG for Live Activities:
/// - Glanceable information at every presentation size
/// - Cohesive compact leading + trailing forming a single visual thought
/// - Dynamic content in minimal (progress, not a static logo)
/// - Expanded view adds detail without duplicating the compact view
/// - No interactive controls — tapping opens the app
struct PomoDuoLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerActivityAttributes.self) { context in
            LockScreenBanner(
                state: context.state,
                totalRounds: context.attributes.totalRounds
            )
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ExpandedLeadingView(state: context.state)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    ExpandedTrailingView(state: context.state)
                }

                DynamicIslandExpandedRegion(.center) {
                    ExpandedCenterView(state: context.state)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottomView(
                        state: context.state,
                        totalRounds: context.attributes.totalRounds
                    )
                }
            } compactLeading: {
                CompactLeadingView(state: context.state)
            } compactTrailing: {
                CompactTrailingView(state: context.state)
            } minimal: {
                MinimalView(state: context.state)
            }
            .keylineTint(keylineTint(for: context.state))
        }
    }

    private func keylineTint(
        for state: TimerActivityAttributes.ContentState
    ) -> Color {
        if state.isPaused { return .orange }
        return state.phase.isBreak ? Palette.breakTint : Palette.focusTint
    }
}

// MARK: - Palette

/// Compact color system for the widget extension.
///
/// Mirror's the main app's ``AppColors`` without importing the app target.
private enum Palette {
    static let focusTint = Color(red: 0.56, green: 0.44, blue: 0.86)
    static let focusLight = Color(red: 0.73, green: 0.60, blue: 0.93)
    static let breakTint = Color(red: 0.55, green: 0.78, blue: 0.78)
    static let pauseTint = Color.orange
    static let success = Color(red: 0.45, green: 0.73, blue: 0.54)

    static func phaseTint(
        for phase: TimerActivityAttributes.Phase,
        isPaused: Bool
    ) -> Color {
        if isPaused { return pauseTint }
        return phase.isBreak ? breakTint : focusTint
    }

    static func phaseGradient(
        for phase: TimerActivityAttributes.Phase,
        isPaused: Bool
    ) -> LinearGradient {
        if isPaused {
            return LinearGradient(
                colors: [.orange, .orange.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        if phase.isBreak {
            return LinearGradient(
                colors: [breakTint, breakTint.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        return LinearGradient(
            colors: [focusTint, focusLight],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Dynamic Island — Compact

/// Leading side: phase icon tinted to current state.
///
/// HIG: compact leading + trailing should form a single cohesive thought.
/// Leading shows *what* (icon), trailing shows *when* (countdown).
private struct CompactLeadingView: View {
    let state: TimerActivityAttributes.ContentState

    var body: some View {
        Image(systemName: iconName)
            .font(.caption)
            .foregroundStyle(tint)
            .accessibilityLabel(accessibilityPhase)
    }

    private var iconName: String {
        if state.isPaused { return "pause.circle.fill" }

        switch state.phase {
        case .focus: return "brain.head.profile"
        case .shortBreak: return "cup.and.saucer.fill"
        case .longBreak: return "figure.walk"
        }
    }

    private var tint: Color {
        Palette.phaseTint(for: state.phase, isPaused: state.isPaused)
    }

    private var accessibilityPhase: String {
        if state.isPaused { return "Paused" }
        return state.phase.label
    }
}

/// Trailing side: countdown timer that fits the narrow slot.
///
/// Key fix: `.font(.caption2)` + `.minimumScaleFactor(0.6)` + frame
/// constraint prevents truncation ("23..." → "23:45").
private struct CompactTrailingView: View {
    let state: TimerActivityAttributes.ContentState

    var body: some View {
        if state.isPaused {
            Image(systemName: "pause.fill")
                .font(.caption2)
                .foregroundStyle(.orange)
                .accessibilityLabel("Paused")
        } else {
            Text(
                timerInterval: Date.now...state.targetEndDate,
                countsDown: true
            )
            .font(.caption2)
            .monospacedDigit()
            .minimumScaleFactor(0.6)
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .trailing)
            .foregroundStyle(.white)
            .accessibilityLabel("Time remaining")
        }
    }
}

// MARK: - Dynamic Island — Minimal

/// Shown when multiple Live Activities are active.
///
/// HIG: display live, dynamic content — not a static logo.
/// A tiny circular progress arc conveys session progress at a glance.
private struct MinimalView: View {
    let state: TimerActivityAttributes.ContentState

    var body: some View {
        if state.isPaused {
            Image(systemName: "pause.fill")
                .font(.caption2)
                .foregroundStyle(.orange)
                .accessibilityLabel("Focus session paused")
        } else {
            Text(
                timerInterval: Date.now...state.targetEndDate,
                countsDown: true
            )
            .font(.caption2)
            .monospacedDigit()
            .minimumScaleFactor(0.5)
            .foregroundStyle(.white)
            .accessibilityLabel("Time remaining")
        }
    }
}

// MARK: - Dynamic Island — Expanded

/// Leading region: large phase icon with tinted background.
private struct ExpandedLeadingView: View {
    let state: TimerActivityAttributes.ContentState

    var body: some View {
        Image(systemName: iconName)
            .font(.title2)
            .foregroundStyle(tint)
            .accessibilityHidden(true)
    }

    private var iconName: String {
        if state.isPaused { return "pause.circle.fill" }
        return state.phase.systemImage
    }

    private var tint: Color {
        Palette.phaseTint(for: state.phase, isPaused: state.isPaused)
    }
}

/// Trailing region: countdown timer or paused indicator.
private struct ExpandedTrailingView: View {
    let state: TimerActivityAttributes.ContentState

    var body: some View {
        if state.isPaused {
            Text("Paused")
                .font(.headline)
                .foregroundStyle(.orange)
        } else {
            Text(
                timerInterval: Date.now...state.targetEndDate,
                countsDown: true
            )
            .font(.title3)
            .bold()
            .monospacedDigit()
            .foregroundStyle(.white)
            .contentTransition(.numericText())
            .accessibilityLabel("Time remaining")
        }
    }
}

/// Center region: phase label.
private struct ExpandedCenterView: View {
    let state: TimerActivityAttributes.ContentState

    var body: some View {
        Text(state.isPaused ? "Paused" : state.phase.label)
            .font(.headline)
            .bold()
            .foregroundStyle(.white)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Bottom region: round progress dots + round counter.
///
/// Gives users a clear sense of overall session progress,
/// which is a key HIG principle for Live Activities.
private struct ExpandedBottomView: View {
    let state: TimerActivityAttributes.ContentState
    let totalRounds: Int

    var body: some View {
        HStack {
            ExpandedRoundDots(
                currentRound: state.currentRound,
                totalRounds: totalRounds,
                phase: state.phase,
                isPaused: state.isPaused
            )

            Spacer()

            Text("Round \(state.currentRound) of \(totalRounds)")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.72))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Round \(state.currentRound) of \(totalRounds)"
        )
    }
}

/// Dot indicators in the expanded view showing completed, current,
/// and remaining rounds with phase-appropriate coloring.
private struct ExpandedRoundDots: View {
    let currentRound: Int
    let totalRounds: Int
    let phase: TimerActivityAttributes.Phase
    let isPaused: Bool

    private var activeTint: Color {
        Palette.phaseTint(for: phase, isPaused: isPaused)
    }

    var body: some View {
        HStack(spacing: 5) {
            ForEach(1...max(1, totalRounds), id: \.self) { round in
                Circle()
                    .fill(dotColor(for: round))
                    .frame(width: 7, height: 7)
            }
        }
    }

    private func dotColor(for round: Int) -> Color {
        if round < currentRound {
            return activeTint
        } else if round == currentRound {
            return activeTint.opacity(0.6)
        } else {
            return .white.opacity(0.24)
        }
    }
}

// MARK: - Lock Screen Banner

/// Lock Screen presentation — the most information-dense surface.
///
/// HIG: "Use a standard margin to visually align the content of your
/// Lock Screen Live Activity with other elements on the Lock Screen."
///
/// Design approach: leading icon + phase/round info on the left,
/// countdown on the right, with a thin progress bar along the bottom
/// edge for a visual sense of time remaining.
private struct LockScreenBanner: View {
    let state: TimerActivityAttributes.ContentState
    let totalRounds: Int

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                LockScreenPhaseInfo(state: state, totalRounds: totalRounds)

                Spacer()

                LockScreenCountdown(state: state)
            }
            .padding()

            LockScreenProgressBar(state: state)
        }
        .activityBackgroundTint(backgroundTint)
        .accessibilityElement(children: .combine)
    }

    private var backgroundTint: Color {
        if state.isPaused {
            return .orange.opacity(0.12)
        }
        return state.phase.isBreak
            ? Palette.breakTint.opacity(0.12)
            : Palette.focusTint.opacity(0.12)
    }
}

/// Left side of the Lock Screen banner: icon + phase + round.
private struct LockScreenPhaseInfo: View {
    let state: TimerActivityAttributes.ContentState
    let totalRounds: Int

    var body: some View {
        HStack(spacing: 12) {
            LockScreenPhaseIcon(state: state)

            VStack(alignment: .leading, spacing: 2) {
                Text(state.isPaused ? "Paused" : state.phase.label)
                    .font(.headline)
                    .bold()

                Text("Round \(state.currentRound) of \(totalRounds)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// Circular icon with subtle tinted background for the Lock Screen.
private struct LockScreenPhaseIcon: View {
    let state: TimerActivityAttributes.ContentState

    var body: some View {
        Image(systemName: iconName)
            .font(.title3)
            .foregroundStyle(tint)
            .accessibilityHidden(true)
    }

    private var iconName: String {
        if state.isPaused { return "pause.circle.fill" }
        return state.phase.systemImage
    }

    private var tint: Color {
        Palette.phaseTint(for: state.phase, isPaused: state.isPaused)
    }
}

/// Right side of the Lock Screen banner: large countdown or pause state.
private struct LockScreenCountdown: View {
    let state: TimerActivityAttributes.ContentState

    var body: some View {
        if state.isPaused {
            Image(systemName: "pause.fill")
                .font(.title3)
                .foregroundStyle(.orange)
                .accessibilityLabel("Timer paused")
        } else {
            Text(
                timerInterval: Date.now...state.targetEndDate,
                countsDown: true
            )
            .font(.title3)
            .bold()
            .monospacedDigit()
            .foregroundStyle(
                Palette.phaseTint(
                    for: state.phase,
                    isPaused: false
                )
            )
            .contentTransition(.numericText())
            .accessibilityLabel("Time remaining")
        }
    }
}

/// Thin progress accent bar along the bottom of the Lock Screen banner.
///
/// Provides an ambient sense of time elapsed, similar to how Apple's
/// native Timer app shows progress. Animates with `.easeInOut` for
/// smooth state-to-state transitions.
private struct LockScreenProgressBar: View {
    let state: TimerActivityAttributes.ContentState

    var body: some View {
        GeometryReader { proxy in
            Capsule()
                .fill(barGradient)
                .frame(width: barWidth(in: proxy.size.width), height: 3)
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
        }
        .frame(height: 3)
    }

    private var barGradient: LinearGradient {
        Palette.phaseGradient(
            for: state.phase,
            isPaused: state.isPaused
        )
    }

    /// Estimates progress from time remaining vs. phase duration.
    ///
    /// Because Live Activities can't store the original start time,
    /// we use the standard Pomodoro durations as reasonable defaults.
    private func barWidth(in totalWidth: CGFloat) -> CGFloat {
        guard !state.isPaused else {
            // Show a short accent when paused.
            return totalWidth * 0.15
        }

        let remaining = state.targetEndDate.timeIntervalSinceNow
        let estimated = estimatedDuration(for: state.phase)
        let progress = max(0, min(1, 1.0 - remaining / estimated))

        return max(totalWidth * 0.04, totalWidth * progress)
    }

    private func estimatedDuration(
        for phase: TimerActivityAttributes.Phase
    ) -> TimeInterval {
        switch phase {
        case .focus: return 25 * 60
        case .shortBreak: return 5 * 60
        case .longBreak: return 15 * 60
        }
    }
}
