import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Widget Entry Point

/// Live Activity rendering for Lock Screen and Dynamic Island.
///
/// Design language modeled after the Apple Clock timer:
/// - Clock-style compact status icon (running/paused) for quick recognition
/// - Phase-aware accent color: purple for focus, teal for breaks, amber when paused
/// - Cohesive compact leading + trailing forming a single visual thought
/// - Minimal state mirrors compact iconography when coexisting with other activities
/// - Expanded view adds detail without duplicating the compact view
/// - Interactive pause/resume and cancel controls in the expanded bottom region
struct PomoDuoLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerActivityAttributes.self) { context in
            LockScreenBanner(
                state: context.state,
                totalRounds: context.attributes.totalRounds
            )
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading, priority: 1) {
                    ExpandedLeadingView(state: context.state)
                }

                DynamicIslandExpandedRegion(.trailing, priority: 2) {
                    ExpandedTrailingView(state: context.state)
                }

                DynamicIslandExpandedRegion(.center) {
                    ExpandedCenterView(
                        state: context.state,
                        totalRounds: context.attributes.totalRounds
                    )
                }

                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottomControlsView(state: context.state)
                }
            } compactLeading: {
                CompactLeadingView(state: context.state)
            } compactTrailing: {
                CompactTrailingView(state: context.state)
            } minimal: {
                MinimalView(state: context.state)
            }
            .keylineTint(Palette.accentTint(for: context.state))
        }
    }
}

// MARK: - Palette

/// Compact color system for the widget extension.
///
/// Mirrors the main app's ``AppColors`` without importing the app target.
/// Includes high-contrast vivid variants for Lock Screen liquid glass.
private enum Palette {
    /// PomoDuo's signature deep lavender.
    static let focusTint = Color(red: 0.56, green: 0.44, blue: 0.86)
    /// Soft lilac for secondary accents.
    static let focusLight = Color(red: 0.73, green: 0.60, blue: 0.93)
    /// High-contrast vivid purple for Lock Screen elements.
    static let focusVivid = Color(red: 0.70, green: 0.55, blue: 1.0)

    static let breakTint = Color(red: 0.55, green: 0.78, blue: 0.78)
    static let breakVivid = Color(red: 0.60, green: 0.88, blue: 0.88)

    static let pauseTint = Color(red: 0.90, green: 0.70, blue: 0.40)

    static let success = Color(red: 0.45, green: 0.73, blue: 0.54)

    /// Phase-aware accent for Dynamic Island elements.
    static func accentTint(
        for state: TimerActivityAttributes.ContentState
    ) -> Color {
        accentTint(for: state.phase, isPaused: state.isPaused)
    }

    static func accentTint(
        for phase: TimerActivityAttributes.Phase,
        isPaused: Bool
    ) -> Color {
        if isPaused { return pauseTint }
        return phase.isBreak ? breakTint : focusTint
    }

    /// High-contrast variant for Lock Screen accents.
    static func accentVivid(
        for state: TimerActivityAttributes.ContentState
    ) -> Color {
        accentVivid(for: state.phase, isPaused: state.isPaused)
    }

    static func accentVivid(
        for phase: TimerActivityAttributes.Phase,
        isPaused: Bool
    ) -> Color {
        if isPaused { return pauseTint }
        return phase.isBreak ? breakVivid : focusVivid
    }
}

// MARK: - Timer Helpers

/// Ensures `Text(timerInterval:)` always receives a valid range.
///
/// If a Live Activity lingers briefly after the countdown expired, the raw
/// range can become `Date.now...pastDate`, which is invalid.
private func safeTimerInterval(
    until targetEndDate: Date
) -> ClosedRange<Date> {
    let now = Date.now
    return now...max(now, targetEndDate)
}

/// Calculates the remaining fraction (0…1) of the current timer phase.
///
/// Returns 1.0 when the full duration remains and 0.0 at expiration.
private func remainingFraction(
    for state: TimerActivityAttributes.ContentState
) -> Double {
    guard state.phaseDuration > 0 else { return 0 }
    if state.isPaused {
        return min(1, state.pausedRemainingSeconds / state.phaseDuration)
    }
    let remaining = max(0, state.targetEndDate.timeIntervalSinceNow)
    return min(1, remaining / state.phaseDuration)
}

/// Formats the frozen remaining time for paused-state display.
///
/// Uses ``TimerActivityAttributes/ContentState/pausedRemainingSeconds``
/// captured at the moment of pausing — the value does not drift.
private func pausedTimeText(
    for state: TimerActivityAttributes.ContentState
) -> String {
    let duration = Duration.seconds(Int(state.pausedRemainingSeconds))
    return duration.formatted(.time(pattern: .minuteSecond))
}

/// Compact iconography that mirrors the Apple Clock timer language.
///
/// Running uses the timer glyph. Paused uses the pause-in-circle glyph.
private struct ClockStatusIconView: View {
    let isPaused: Bool
    let tint: Color
    let font: Font

    var body: some View {
        Image(systemName: isPaused ? "pause.circle" : "timer")
            .font(font)
            .foregroundStyle(tint)
    }
}

// MARK: - Dynamic Island — Compact

/// Leading side: Clock-style timer status icon.
private struct CompactLeadingView: View {
    let state: TimerActivityAttributes.ContentState

    var body: some View {
        ClockStatusIconView(
            isPaused: state.isPaused,
            tint: Palette.accentTint(for: state),
            font: .headline
        )
        .frame(width: 22, height: 22)
        .accessibilityLabel(state.isPaused ? "Paused timer" : "Running timer")
    }
}

/// Trailing side: countdown in the current phase's accent color.
private struct CompactTrailingView: View {
    let state: TimerActivityAttributes.ContentState

    var body: some View {
        CompactCountdownValueView(state: state)
    }
}

/// Trailing compact countdown with a fixed footprint in both running/paused states.
///
/// Keeping a stable width prevents single-sided compact island collapse when
/// the running timer text updates.
private struct CompactCountdownValueView: View {
    let state: TimerActivityAttributes.ContentState

    private var placeholderTime: String {
        state.phaseDuration >= 3600 ? "00:00:00" : "00:00"
    }

    var body: some View {
        Text(placeholderTime)
            .font(.headline)
            .bold()
            .monospacedDigit()
            .hidden()
            .overlay(alignment: .trailing) {
                Group {
                    if state.isPaused {
                        Text(pausedTimeText(for: state))
                            .accessibilityLabel(
                                "Paused, \(pausedTimeText(for: state)) remaining"
                            )
                    } else {
                        Text(state.targetEndDate, style: .timer)
                            .accessibilityLabel("Time remaining")
                    }
                }
                .font(.headline)
                .bold()
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(Palette.accentTint(for: state))
                .contentTransition(.numericText())
            }
            .layoutPriority(1)
    }
}

// MARK: - Dynamic Island — Minimal

/// Shown when multiple Live Activities are active.
///
/// HIG: display live, dynamic content that maps to compact semantics.
private struct MinimalView: View {
    let state: TimerActivityAttributes.ContentState

    private var accessibilityStatusLabel: String {
        let phaseText = state.phase.label.lowercased()
        if state.isPaused {
            return "Paused \(phaseText) timer"
        }
        return "Running \(phaseText) timer"
    }

    var body: some View {
        ClockStatusIconView(
            isPaused: state.isPaused,
            tint: Palette.accentTint(for: state),
            font: .title3
        )
        .frame(width: 24, height: 24)
        .accessibilityLabel(accessibilityStatusLabel)
    }
}

// MARK: - Dynamic Island — Expanded

/// Leading region: larger progress ring.
private struct ExpandedLeadingView: View {
    let state: TimerActivityAttributes.ContentState

    private var tint: Color {
        Palette.accentTint(for: state)
    }

    private var centerSymbol: String {
        state.isPaused ? "pause.fill" : state.phase.systemImage
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(state.isPaused ? 0.95 : 0.24), lineWidth: 3.5)

            if !state.isPaused {
                Circle()
                    .trim(from: 0, to: max(0.001, remainingFraction(for: state)))
                    .stroke(
                        tint,
                        style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }

            Image(systemName: centerSymbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .accessibilityHidden(true)
        }
        .frame(width: 44, height: 44)
        .accessibilityLabel(
            state.isPaused
                ? "Paused \(state.phase.label.lowercased()) timer"
                : "\(state.phase.label) timer progress"
        )
        .accessibilityValue(
            state.isPaused
                ? pausedTimeText(for: state)
                : "\(Int((1 - remainingFraction(for: state)) * 100)) percent complete"
        )
    }
}

/// Trailing region: high-contrast countdown for readability.
private struct ExpandedTrailingView: View {
    let state: TimerActivityAttributes.ContentState

    var body: some View {
        Group {
            if state.isPaused {
                Text(pausedTimeText(for: state))
                    .accessibilityLabel(
                        "Paused, \(pausedTimeText(for: state)) remaining"
                    )
            } else {
                Text(
                    timerInterval: safeTimerInterval(until: state.targetEndDate),
                    countsDown: true
                )
                .accessibilityLabel("Time remaining")
            }
        }
        .font(.system(.title3, design: .rounded))
        .bold()
        .monospacedDigit()
        .foregroundStyle(.white)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .contentTransition(.numericText())
    }
}

/// Center region: phase label and round indicator.
private struct ExpandedCenterView: View {
    let state: TimerActivityAttributes.ContentState
    let totalRounds: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(state.isPaused ? "Paused" : state.phase.label)
                .font(.headline)
                .bold()
                .foregroundStyle(.white)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)

            Text("Round \(state.currentRound) of \(totalRounds)")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))
                .monospacedDigit()
                .lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Round \(state.currentRound) of \(totalRounds)"
        )
    }
}

// MARK: - Dynamic Island — Expanded Bottom Controls

/// Interactive controls in the expanded Dynamic Island's bottom region.
///
/// Provides Pause/Resume and Cancel buttons powered by ``LiveActivityIntent``
/// conformances. These execute in the widget extension process, update the
/// Live Activity inline, and write a bridge command for the main app.
private struct ExpandedBottomControlsView: View {
    let state: TimerActivityAttributes.ContentState

    private var tint: Color {
        Palette.accentTint(for: state)
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(intent: StopTimerIntent()) {
                Text("Cancel")
                    .font(.subheadline)
                    .bold()
                    .frame(maxWidth: .infinity)
            }
            .tint(Color.white.opacity(0.25))
            .buttonBorderShape(.capsule)

            Button(intent: TogglePauseIntent()) {
                Text(state.isPaused ? "Resume" : "Pause")
                    .font(.subheadline)
                    .bold()
                    .frame(maxWidth: .infinity)
            }
            .tint(tint)
            .buttonBorderShape(.capsule)
        }
        .padding(.top, 4)
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
        Palette.accentVivid(for: state)
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                LockScreenPhaseIconBadgeView(
                    state: state,
                    tint: accentColor
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(state.isPaused ? "Paused" : state.phase.label)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text("Round \(state.currentRound) of \(totalRounds)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .layoutPriority(1)

                if state.isPaused {
                    Text("Paused")
                        .font(.title2)
                        .bold()
                        .foregroundStyle(accentColor)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .accessibilityLabel("Timer paused")
                } else {
                    LockScreenRunningCountdownView(state: state)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

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
            return Palette.pauseTint.opacity(0.15)
        }
        return state.phase.isBreak
            ? Palette.breakTint.opacity(0.15)
            : Palette.focusTint.opacity(0.15)
    }
}

/// Leading lock-screen glyph with a deterministic pulse phase.
///
/// Lock-screen Live Activities don't reliably run continuous custom animation
/// loops. Instead this view reacts to ``TimerActivityAttributes.ContentState``
/// pulse-phase updates produced by the app timer flow.
private struct LockScreenPhaseIconBadgeView: View {
    let state: TimerActivityAttributes.ContentState
    let tint: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var symbolName: String {
        if state.isPaused { return "pause.fill" }
        if state.phase == .focus && state.pulsePhase {
            return "brain.head.profile.fill"
        }
        return state.phase.systemImage
    }

    private var shouldPulse: Bool {
        !reduceMotion && !state.isPaused && state.phase == .focus
    }

    var body: some View {
        let isPulsed = shouldPulse && state.pulsePhase

        ZStack {
            Circle()
                .stroke(
                    tint.opacity(isPulsed ? 0.35 : 0.14),
                    lineWidth: 1.2
                )
                .scaleEffect(isPulsed ? 1.22 : 1.0)

            Image(systemName: symbolName)
                .symbolRenderingMode(.hierarchical)
                .font(.title3)
                .bold()
                .foregroundStyle(tint)
                .scaleEffect(isPulsed ? 1.16 : 1.0)
                .opacity(isPulsed ? 1.0 : 0.86)
        }
        .frame(width: 36, height: 36)
        .background(tint.opacity(0.25), in: .circle)
        .accessibilityHidden(true)
    }
}

/// Running-state lock screen countdown pinned to the trailing edge.
///
/// Uses a hidden monospaced template to stabilize width as values tick.
private struct LockScreenRunningCountdownView: View {
    let state: TimerActivityAttributes.ContentState

    private var placeholderTime: String {
        state.phaseDuration >= 3600 ? "00:00:00" : "00:00"
    }

    var body: some View {
        Text(placeholderTime)
            .font(.system(.title, design: .rounded))
            .bold()
            .monospacedDigit()
            .hidden()
            .overlay(alignment: .trailing) {
                Text(
                    timerInterval: safeTimerInterval(until: state.targetEndDate),
                    countsDown: true
                )
                .font(.system(.title, design: .rounded))
                .bold()
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
                .accessibilityLabel("Time remaining")
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
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
        let vivid = Palette.accentVivid(for: phase, isPaused: isPaused)
        if round < currentRound {
            return AnyShapeStyle(vivid)
        } else if round == currentRound {
            return AnyShapeStyle(vivid.opacity(0.6))
        } else {
            return AnyShapeStyle(.primary.opacity(0.15))
        }
    }
}

// MARK: - Preview Data

extension TimerActivityAttributes {
    fileprivate static let preview = TimerActivityAttributes(totalRounds: 4)
}

extension TimerActivityAttributes.ContentState {
    fileprivate static let focusActive = TimerActivityAttributes.ContentState(
        phase: .focus,
        currentRound: 2,
        targetEndDate: .now.addingTimeInterval(25 * 60),
        isPaused: false,
        phaseDuration: 25 * 60
    )

    fileprivate static let shortBreakActive =
        TimerActivityAttributes.ContentState(
            phase: .shortBreak,
            currentRound: 2,
            targetEndDate: .now.addingTimeInterval(5 * 60),
            isPaused: false,
            phaseDuration: 5 * 60
        )

    fileprivate static let longBreakActive =
        TimerActivityAttributes.ContentState(
            phase: .longBreak,
            currentRound: 4,
            targetEndDate: .now.addingTimeInterval(15 * 60),
            isPaused: false,
            phaseDuration: 15 * 60
        )

    fileprivate static let paused = TimerActivityAttributes.ContentState(
        phase: .focus,
        currentRound: 3,
        targetEndDate: .now.addingTimeInterval(12 * 60 + 45),
        isPaused: true,
        phaseDuration: 25 * 60,
        pausedRemainingSeconds: 12 * 60 + 45
    )
}

// MARK: - Dynamic Island Previews

#Preview(
    "Expanded",
    as: .dynamicIsland(.expanded),
    using: TimerActivityAttributes.preview
) {
    PomoDuoLiveActivity()
} contentStates: {
    TimerActivityAttributes.ContentState.focusActive
    TimerActivityAttributes.ContentState.shortBreakActive
    TimerActivityAttributes.ContentState.longBreakActive
    TimerActivityAttributes.ContentState.paused
}

#Preview(
    "Compact",
    as: .dynamicIsland(.compact),
    using: TimerActivityAttributes.preview
) {
    PomoDuoLiveActivity()
} contentStates: {
    TimerActivityAttributes.ContentState.focusActive
    TimerActivityAttributes.ContentState.shortBreakActive
    TimerActivityAttributes.ContentState.longBreakActive
    TimerActivityAttributes.ContentState.paused
}

#Preview(
    "Minimal",
    as: .dynamicIsland(.minimal),
    using: TimerActivityAttributes.preview
) {
    PomoDuoLiveActivity()
} contentStates: {
    TimerActivityAttributes.ContentState.focusActive
    TimerActivityAttributes.ContentState.shortBreakActive
    TimerActivityAttributes.ContentState.longBreakActive
    TimerActivityAttributes.ContentState.paused
}

// MARK: - Lock Screen Preview

#Preview("Lock Screen", as: .content, using: TimerActivityAttributes.preview) {
    PomoDuoLiveActivity()
} contentStates: {
    TimerActivityAttributes.ContentState.focusActive
    TimerActivityAttributes.ContentState.shortBreakActive
    TimerActivityAttributes.ContentState.longBreakActive
    TimerActivityAttributes.ContentState.paused
}
