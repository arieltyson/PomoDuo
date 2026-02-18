import ActivityKit
import SwiftUI
import WidgetKit

/// Live Activity rendering for Lock Screen and Dynamic Island.
struct PomoDuoLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerActivityAttributes.self) { context in
            LockScreenBanner(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ExpandedPhaseIcon(
                        phase: context.state.phase,
                        isPaused: context.state.isPaused
                    )
                }

                DynamicIslandExpandedRegion(.trailing) {
                    ExpandedCountdownLabel(state: context.state)
                }

                DynamicIslandExpandedRegion(.center) {
                    Text(
                        context.state.isPaused
                            ? "Paused" : context.state.phase.label
                    )
                    .font(.headline)
                    .bold()
                    .foregroundStyle(.white)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        RoundDots(
                            currentRound: context.state.currentRound,
                            totalRounds: context.attributes.totalRounds
                        )

                        Spacer()

                        Text(
                            "Round \(context.state.currentRound) of \(context.attributes.totalRounds)"
                        )
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.72))
                    }
                }
            } compactLeading: {
                Image(systemName: compactIconName(for: context.state))
                    .font(.caption)
                    .foregroundStyle(compactTint(for: context.state))
            } compactTrailing: {
                CompactCountdownLabel(state: context.state)
            } minimal: {
                MinimalCountdownLabel(state: context.state)
            }
        }
    }

    private func compactIconName(
        for state: TimerActivityAttributes.ContentState
    ) -> String {
        if state.isPaused {
            return "pause.circle.fill"
        }

        switch state.phase {
        case .focus:
            return "brain.fill"
        case .shortBreak:
            return "cup.and.saucer.fill"
        case .longBreak:
            return "figure.walk"
        }
    }

    private func compactTint(for state: TimerActivityAttributes.ContentState)
        -> Color
    {
        if state.isPaused {
            return .orange
        }

        return state.phase.isBreak ? .teal : .indigo
    }
}

private struct LockScreenBanner: View {
    let context: ActivityViewContext<TimerActivityAttributes>

    var body: some View {
        HStack {
            ExpandedPhaseIcon(
                phase: context.state.phase,
                isPaused: context.state.isPaused
            )

            VStack(alignment: .leading) {
                Text(
                    context.state.isPaused
                        ? "Paused" : context.state.phase.label
                )
                .font(.headline)
                .bold()

                Text(
                    "Round \(context.state.currentRound) of \(context.attributes.totalRounds)"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            ExpandedCountdownLabel(state: context.state)
        }
        .padding()
        .activityBackgroundTint(
            context.state.phase.isBreak
                ? .teal.opacity(0.15) : .purple.opacity(0.15)
        )
    }
}

private struct ExpandedPhaseIcon: View {
    let phase: TimerActivityAttributes.Phase
    let isPaused: Bool

    var body: some View {
        Image(systemName: isPaused ? "pause.circle.fill" : phase.systemImage)
            .font(.title2)
            .foregroundStyle(color)
    }

    private var color: Color {
        if isPaused {
            .orange
        } else {
            phase.isBreak ? .teal : .purple
        }
    }
}

private struct ExpandedCountdownLabel: View {
    let state: TimerActivityAttributes.ContentState

    var body: some View {
        if state.isPaused {
            Image(systemName: "pause.fill")
                .foregroundStyle(.orange)
        } else {
            Text(
                timerInterval: Date.now...state.targetEndDate,
                countsDown: true
            )
            .font(.headline)
            .bold()
            .monospacedDigit()
            .foregroundStyle(.white)
        }
    }
}

private struct CompactCountdownLabel: View {
    let state: TimerActivityAttributes.ContentState

    var body: some View {
        if state.isPaused {
            Image(systemName: "pause.fill")
                .font(.caption)
                .foregroundStyle(.orange)
        } else {
            Text(
                timerInterval: Date.now...state.targetEndDate,
                countsDown: true
            )
            .font(.caption)
            .bold()
            .monospacedDigit()
            .foregroundStyle(.white)
        }
    }
}

private struct MinimalCountdownLabel: View {
    let state: TimerActivityAttributes.ContentState

    var body: some View {
        if state.isPaused {
            Image(systemName: "pause.fill")
                .font(.caption2)
                .foregroundStyle(.orange)
        } else {
            Text(
                timerInterval: Date.now...state.targetEndDate,
                countsDown: true
            )
            .font(.caption2)
            .monospacedDigit()
            .foregroundStyle(.white)
        }
    }
}

private struct RoundDots: View {
    let currentRound: Int
    let totalRounds: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...max(1, totalRounds), id: \.self) { round in
                Circle()
                    .fill(color(for: round))
                    .frame(width: 6, height: 6)
            }
        }
    }

    private func color(for round: Int) -> Color {
        if round < currentRound {
            .indigo
        } else if round == currentRound {
            .indigo.opacity(0.8)
        } else {
            .white.opacity(0.3)
        }
    }
}
