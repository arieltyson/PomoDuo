//
//  PomoDuoLiveActivity.swift
//  PomoDuoWidgetExtension
//
//  Created by Codex on 2/15/26.
//

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
                    PhaseIcon(phase: context.state.phase, isPaused: context.state.isPaused)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    CountdownLabel(state: context.state)
                }

                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.isPaused ? "Paused" : context.state.phase.label)
                        .font(.headline)
                        .bold()
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        RoundDots(
                            currentRound: context.state.currentRound,
                            totalRounds: context.attributes.totalRounds
                        )

                        Spacer()

                        Text("Round \(context.state.currentRound) of \(context.attributes.totalRounds)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.phase.systemImage)
                    .foregroundStyle(context.state.phase.isBreak ? .teal : .purple)
            } compactTrailing: {
                CountdownLabel(state: context.state)
            } minimal: {
                CountdownLabel(state: context.state)
            }
        }
    }
}

private struct LockScreenBanner: View {
    let context: ActivityViewContext<TimerActivityAttributes>

    var body: some View {
        HStack {
            PhaseIcon(phase: context.state.phase, isPaused: context.state.isPaused)

            VStack(alignment: .leading) {
                Text(context.state.isPaused ? "Paused" : context.state.phase.label)
                    .font(.headline)
                    .bold()

                Text("Round \(context.state.currentRound) of \(context.attributes.totalRounds)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            CountdownLabel(state: context.state)
        }
        .padding()
        .activityBackgroundTint(context.state.phase.isBreak ? .teal.opacity(0.15) : .purple.opacity(0.15))
    }
}

private struct PhaseIcon: View {
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

private struct CountdownLabel: View {
    let state: TimerActivityAttributes.ContentState

    var body: some View {
        if state.isPaused {
            Image(systemName: "pause.fill")
                .foregroundStyle(.orange)
        } else {
            Text(timerInterval: Date.now...state.targetEndDate, countsDown: true)
                .font(.headline)
                .bold()
                .monospacedDigit()
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
            .purple
        } else if round == currentRound {
            .purple.opacity(0.8)
        } else {
            .secondary.opacity(0.3)
        }
    }
}
