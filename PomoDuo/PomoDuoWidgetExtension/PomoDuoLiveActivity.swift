import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Widget Entry Point

/// Live Activity rendering for Lock Screen and Dynamic Island.
///
/// Design language modeled after the Apple Clock timer:
/// - Circular progress ring as the primary visual element
/// - Accent-colored countdown text for at-a-glance legibility
/// - Cohesive compact leading + trailing forming a single visual thought
/// - Dynamic content in minimal (progress ring, not a static logo)
/// - Expanded view adds detail without duplicating the compact view
/// - Interactive pause/resume and stop controls in the expanded bottom region
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
                        .dynamicIsland(verticalPlacement: .belowIfTooWide)
                }

                DynamicIslandExpandedRegion(.trailing, priority: 2) {
                    ExpandedTrailingView(state: context.state)
                        .dynamicIsland(verticalPlacement: .belowIfTooWide)
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

// MARK: - Timer Ring Components

/// Circular progress ring modeled after the Apple Clock timer.
///
/// Draws a dim track ring behind a bright fill arc that depletes clockwise
/// from 12 o'clock as time elapses. The system periodically re-renders
/// the Live Activity, advancing the fill to the current progress.
private struct TimerRingView: View {
    let fraction: Double
    let tint: Color
    let lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.25), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: max(0.001, fraction))
                .stroke(
                    tint,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
    }
}

/// Ring with pause icon, shown when the timer is paused.
///
/// A complete ring with centered pause icon communicates the paused
/// state at every Dynamic Island presentation size.
private struct PausedRingView: View {
    let tint: Color
    let lineWidth: CGFloat
    let iconFont: Font

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint, lineWidth: lineWidth)

            Image(systemName: "pause.fill")
                .font(iconFont)
                .foregroundStyle(tint)
        }
    }
}

// MARK: - Dynamic Island — Compact

/// Leading side: circular progress ring tinted to current phase.
///
/// HIG: compact leading + trailing should form a single cohesive thought.
/// Leading shows *progress* (ring), trailing shows *time* (countdown).
private struct CompactLeadingView: View {
    let state: TimerActivityAttributes.ContentState

    private var tint: Color {
        Palette.accentTint(for: state)
    }

    var body: some View {
        Group {
            if state.isPaused {
                PausedRingView(
                    tint: tint,
                    lineWidth: 2,
                    iconFont: .system(size: 7, weight: .bold)
                )
            } else {
                TimerRingView(
                    fraction: remainingFraction(for: state),
                    tint: tint,
                    lineWidth: 2
                )
            }
        }
        .frame(width: 22, height: 22)
        .accessibilityLabel(state.isPaused ? "Paused" : state.phase.label)
    }
}

/// Trailing side: countdown in the phase accent color.
private struct CompactTrailingView: View {
    let state: TimerActivityAttributes.ContentState

    private var tint: Color {
        Palette.accentTint(for: state)
    }

    var body: some View {
        if state.isPaused {
            Text(pausedTimeText(for: state))
                .font(.caption2)
                .bold()
                .monospacedDigit()
                .fixedSize(horizontal: true, vertical: false)
                .foregroundStyle(tint)
                .accessibilityLabel(
                    "Paused, \(pausedTimeText(for: state)) remaining"
                )
        } else {
            Text(
                timerInterval: safeTimerInterval(until: state.targetEndDate),
                countsDown: true
            )
            .font(.caption2)
            .bold()
            .monospacedDigit()
            .fixedSize(horizontal: true, vertical: false)
            .foregroundStyle(tint)
            .accessibilityLabel("Time remaining")
        }
    }
}

// MARK: - Dynamic Island — Minimal

/// Shown when multiple Live Activities are active.
///
/// HIG: display live, dynamic content — not a static logo.
/// The progress ring continuously conveys time remaining.
private struct MinimalView: View {
    let state: TimerActivityAttributes.ContentState

    private var tint: Color {
        Palette.accentTint(for: state)
    }

    var body: some View {
        Group {
            if state.isPaused {
                PausedRingView(
                    tint: tint,
                    lineWidth: 2,
                    iconFont: .system(size: 8, weight: .bold)
                )
            } else {
                TimerRingView(
                    fraction: remainingFraction(for: state),
                    tint: tint,
                    lineWidth: 2
                )
            }
        }
        .frame(width: 24, height: 24)
        .accessibilityLabel(
            state.isPaused ? "Focus session paused" : "Time remaining"
        )
    }
}

// MARK: - Dynamic Island — Expanded

/// Leading region: larger progress ring.
private struct ExpandedLeadingView: View {
    let state: TimerActivityAttributes.ContentState

    private var tint: Color {
        Palette.accentTint(for: state)
    }

    var body: some View {
        Group {
            if state.isPaused {
                PausedRingView(
                    tint: tint,
                    lineWidth: 3,
                    iconFont: .system(size: 14, weight: .bold)
                )
            } else {
                TimerRingView(
                    fraction: remainingFraction(for: state),
                    tint: tint,
                    lineWidth: 3
                )
            }
        }
        .frame(width: 36, height: 36)
        .accessibilityHidden(true)
    }
}

/// Trailing region: countdown in accent color or paused indicator.
private struct ExpandedTrailingView: View {
    let state: TimerActivityAttributes.ContentState

    private var tint: Color {
        Palette.accentTint(for: state)
    }

    var body: some View {
        if state.isPaused {
            VStack(spacing: 2) {
                Text(pausedTimeText(for: state))
                    .font(.title3)
                    .bold()
                    .monospacedDigit()
                    .foregroundStyle(tint)

                Text("Paused")
                    .font(.caption2)
                    .foregroundStyle(tint.opacity(0.7))
            }
        } else {
            Text(
                timerInterval: safeTimerInterval(until: state.targetEndDate),
                countsDown: true
            )
            .font(.title3)
            .bold()
            .monospacedDigit()
            .foregroundStyle(tint)
            .contentTransition(.numericText())
            .accessibilityLabel("Time remaining")
        }
    }
}

/// Center region: phase label and round indicator.
private struct ExpandedCenterView: View {
    let state: TimerActivityAttributes.ContentState
    let totalRounds: Int

    var body: some View {
        VStack(spacing: 2) {
            Text(state.isPaused ? "Paused" : state.phase.label)
                .font(.headline)
                .bold()
                .foregroundStyle(.white)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)

            Text("Round \(state.currentRound) of \(totalRounds)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .lineLimit(1)
        }
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Round \(state.currentRound) of \(totalRounds)"
        )
    }
}

// MARK: - Dynamic Island — Expanded Bottom Controls

/// Interactive controls in the expanded Dynamic Island's bottom region.
///
/// Provides Pause/Resume and Stop buttons powered by ``LiveActivityIntent``
/// conformances. These execute in the widget extension process, update the
/// Live Activity inline, and write a bridge command for the main app.
private struct ExpandedBottomControlsView: View {
    let state: TimerActivityAttributes.ContentState

    private var tint: Color {
        Palette.accentTint(for: state)
    }

    var body: some View {
        HStack(spacing: 16) {
            Button(intent: StopTimerIntent()) {
                Label("Stop", systemImage: "stop.fill")
                    .font(.caption)
                    .bold()
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(.red.opacity(0.6), in: .capsule)
            }
            .buttonStyle(.plain)

            Button(intent: TogglePauseIntent()) {
                Label(
                    state.isPaused ? "Resume" : "Pause",
                    systemImage: state.isPaused ? "play.fill" : "pause.fill"
                )
                .font(.caption)
                .bold()
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(tint.opacity(0.6), in: .capsule)
            }
            .buttonStyle(.plain)
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
/// Layout: `[ring] [phase / round] ———[countdown]`
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
                Group {
                    if state.isPaused {
                        PausedRingView(
                            tint: accentColor,
                            lineWidth: 2.5,
                            iconFont: .system(size: 12, weight: .bold)
                        )
                    } else {
                        TimerRingView(
                            fraction: remainingFraction(for: state),
                            tint: accentColor,
                            lineWidth: 2.5
                        )
                    }
                }
                .frame(width: 36, height: 36)
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
                        .foregroundStyle(accentColor)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .accessibilityLabel("Timer paused")
                } else {
                    Text(
                        timerInterval: safeTimerInterval(
                            until: state.targetEndDate
                        ),
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
            return Palette.pauseTint.opacity(0.15)
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

private extension TimerActivityAttributes {
    static let preview = TimerActivityAttributes(totalRounds: 4)
}

private extension TimerActivityAttributes.ContentState {
    static let focusActive = TimerActivityAttributes.ContentState(
        phase: .focus,
        currentRound: 2,
        targetEndDate: .now.addingTimeInterval(25 * 60),
        isPaused: false,
        phaseDuration: 25 * 60
    )

    static let shortBreakActive = TimerActivityAttributes.ContentState(
        phase: .shortBreak,
        currentRound: 2,
        targetEndDate: .now.addingTimeInterval(5 * 60),
        isPaused: false,
        phaseDuration: 5 * 60
    )

    static let longBreakActive = TimerActivityAttributes.ContentState(
        phase: .longBreak,
        currentRound: 4,
        targetEndDate: .now.addingTimeInterval(15 * 60),
        isPaused: false,
        phaseDuration: 15 * 60
    )

    static let paused = TimerActivityAttributes.ContentState(
        phase: .focus,
        currentRound: 3,
        targetEndDate: .now.addingTimeInterval(12 * 60 + 45),
        isPaused: true,
        phaseDuration: 25 * 60,
        pausedRemainingSeconds: 12 * 60 + 45
    )
}

// MARK: - Dynamic Island Previews

#Preview("Expanded", as: .dynamicIsland(.expanded), using: TimerActivityAttributes.preview) {
    PomoDuoLiveActivity()
} contentStates: {
    TimerActivityAttributes.ContentState.focusActive
    TimerActivityAttributes.ContentState.shortBreakActive
    TimerActivityAttributes.ContentState.longBreakActive
    TimerActivityAttributes.ContentState.paused
}

#Preview("Compact", as: .dynamicIsland(.compact), using: TimerActivityAttributes.preview) {
    PomoDuoLiveActivity()
} contentStates: {
    TimerActivityAttributes.ContentState.focusActive
    TimerActivityAttributes.ContentState.shortBreakActive
    TimerActivityAttributes.ContentState.longBreakActive
    TimerActivityAttributes.ContentState.paused
}

#Preview("Minimal", as: .dynamicIsland(.minimal), using: TimerActivityAttributes.preview) {
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
