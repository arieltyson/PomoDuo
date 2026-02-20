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
/// Mirrors the main app's ``AppColors`` without importing the app target.
/// Includes high-contrast vivid variants for Lock Screen liquid glass.
private enum Palette {
    static let focusTint = Color(red: 0.56, green: 0.44, blue: 0.86)
    static let focusLight = Color(red: 0.73, green: 0.60, blue: 0.93)
    static let breakTint = Color(red: 0.55, green: 0.78, blue: 0.78)
    static let pauseTint = Color.orange
    static let success = Color(red: 0.45, green: 0.73, blue: 0.54)

    /// High-contrast tint for Lock Screen elements.
    static let focusVivid = Color(red: 0.70, green: 0.55, blue: 1.0)
    static let breakVivid = Color(red: 0.60, green: 0.88, blue: 0.88)

    static func phaseTint(
        for phase: TimerActivityAttributes.Phase,
        isPaused: Bool
    ) -> Color {
        if isPaused { return pauseTint }
        return phase.isBreak ? breakTint : focusTint
    }

    /// High-contrast variant for Lock Screen accents.
    static func phaseVivid(
        for phase: TimerActivityAttributes.Phase,
        isPaused: Bool
    ) -> Color {
        if isPaused { return pauseTint }
        return phase.isBreak ? breakVivid : focusVivid
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

/// Dot indicators in the expanded Dynamic Island view.
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
/// The countdown `Text` uses `.frame(maxWidth: .infinity, alignment: .trailing)`
/// to claim remaining space and right-align, avoiding `Spacer()` which
/// does not reliably expand in Live Activity Lock Screen contexts.
///
/// Layout: `[icon] [phase / round] ———[countdown]`
///         `[====  round bar segments  ====]`
private struct LockScreenBanner: View {
    let state: TimerActivityAttributes.ContentState
    let totalRounds: Int

    private var accentColor: Color {
        Palette.phaseVivid(for: state.phase, isPaused: state.isPaused)
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(
                    systemName: state.isPaused
                        ? "pause.fill"
                        : state.phase.systemImage
                )
                .font(.title3)
                .foregroundStyle(accentColor)
                .frame(width: 36, height: 36)
                .background(accentColor.opacity(0.25), in: .circle)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(state.isPaused ? "Paused" : state.phase.label)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text("Round \(state.currentRound) of \(totalRounds)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if state.isPaused {
                    Text("Paused")
                        .font(.title2)
                        .bold()
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .accessibilityLabel("Timer paused")
                } else {
                    Text(
                        timerInterval: Date.now...state.targetEndDate,
                        countsDown: true
                    )
                    .font(.system(.title, design: .rounded))
                    .bold()
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .accessibilityLabel("Time remaining")
                }
            }

            LockScreenRoundBar(
                currentRound: state.currentRound,
                totalRounds: totalRounds,
                phase: state.phase,
                isPaused: state.isPaused
            )
        }
        .padding()
        .activityBackgroundTint(backgroundTint)
        .accessibilityElement(children: .combine)
    }

    private var backgroundTint: Color {
        if state.isPaused {
            return .orange.opacity(0.15)
        }
        return state.phase.isBreak
            ? Palette.breakTint.opacity(0.15)
            : Palette.focusTint.opacity(0.15)
    }
}

/// Full-width segmented round progress bar.
///
/// Each round is a capsule — completed rounds are filled with the
/// vivid phase tint, current round is partially opaque, remaining
/// rounds use a dim primary fill. Visible on any wallpaper.
private struct LockScreenRoundBar: View {
    let currentRound: Int
    let totalRounds: Int
    let phase: TimerActivityAttributes.Phase
    let isPaused: Bool

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...max(1, totalRounds), id: \.self) { round in
                Capsule()
                    .fill(segmentFill(for: round))
                    .frame(height: 5)
            }
        }
        .accessibilityHidden(true)
    }

    private func segmentFill(for round: Int) -> some ShapeStyle {
        let vivid = Palette.phaseVivid(for: phase, isPaused: isPaused)
        if round < currentRound {
            return AnyShapeStyle(vivid)
        } else if round == currentRound {
            return AnyShapeStyle(vivid.opacity(0.6))
        } else {
            return AnyShapeStyle(.primary.opacity(0.15))
        }
    }
}
