//
//  TimerControlsView.swift
//  PomoDuo
//
//  Created by Codex on 2/15/26.
//

import SwiftUI

/// Adaptive timer controls for idle, active, and completed states.
struct TimerControlsView: View {
    let isRunning: Bool
    let isPaused: Bool
    let isComplete: Bool

    let onStart: () -> Void
    let onPause: () -> Void
    let onResume: () -> Void
    let onStop: () -> Void
    let onSkip: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if isComplete {
                CompletedControls(onSkip: onSkip)
            } else if isRunning {
                ActiveControls(
                    isPaused: isPaused,
                    onPause: onPause,
                    onResume: onResume,
                    onStop: onStop,
                    onSkip: onSkip
                )
            } else {
                IdleControls(onStart: onStart)
            }
        }
        .animation(reduceMotion ? .none : .easeInOut(duration: 0.3), value: isRunning)
        .animation(reduceMotion ? .none : .easeInOut(duration: 0.3), value: isPaused)
        .animation(reduceMotion ? .none : .easeInOut(duration: 0.3), value: isComplete)
    }
}

private struct IdleControls: View {
    let onStart: () -> Void

    var body: some View {
        Button("Start Focus", systemImage: "play.fill", action: onStart)
            .buttonStyle(.borderedProminent)
            .tint(AppColors.lavender)
            .controlSize(.large)
            .accessibilityHint("Begins a new focus session.")
    }
}

private struct ActiveControls: View {
    let isPaused: Bool
    let onPause: () -> Void
    let onResume: () -> Void
    let onStop: () -> Void
    let onSkip: () -> Void

    var body: some View {
        HStack {
            Button("Stop", systemImage: "stop.fill", action: onStop)
                .buttonStyle(.bordered)
                .tint(.secondary)
                .accessibilityHint("Ends the session and resets the timer.")

            if isPaused {
                Button("Resume", systemImage: "play.fill", action: onResume)
                    .buttonStyle(.borderedProminent)
                    .tint(AppColors.lavender)
                    .controlSize(.large)
                    .accessibilityHint("Continues the paused timer.")
            } else {
                Button("Pause", systemImage: "pause.fill", action: onPause)
                    .buttonStyle(.borderedProminent)
                    .tint(AppColors.pauseTint)
                    .controlSize(.large)
                    .accessibilityHint("Pauses the running timer.")
            }

            Button("Skip", systemImage: "forward.fill", action: onSkip)
                .buttonStyle(.bordered)
                .tint(.secondary)
                .accessibilityHint("Skips to the next phase.")
        }
    }
}

private struct CompletedControls: View {
    let onSkip: () -> Void

    var body: some View {
        Button("Continue", systemImage: "arrow.right", action: onSkip)
            .buttonStyle(.borderedProminent)
            .tint(AppColors.success)
            .controlSize(.large)
            .accessibilityHint("Moves to the next phase.")
    }
}
