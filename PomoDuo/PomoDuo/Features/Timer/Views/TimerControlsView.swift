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
        .animation(.easeInOut(duration: 0.3), value: isRunning)
        .animation(.easeInOut(duration: 0.3), value: isPaused)
        .animation(.easeInOut(duration: 0.3), value: isComplete)
    }
}

private struct IdleControls: View {
    let onStart: () -> Void

    var body: some View {
        Button("Start Focus", systemImage: "play.fill", action: onStart)
            .buttonStyle(.borderedProminent)
            .tint(AppColors.lavender)
            .controlSize(.large)
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

            if isPaused {
                Button("Resume", systemImage: "play.fill", action: onResume)
                    .buttonStyle(.borderedProminent)
                    .tint(AppColors.lavender)
                    .controlSize(.large)
            } else {
                Button("Pause", systemImage: "pause.fill", action: onPause)
                    .buttonStyle(.borderedProminent)
                    .tint(AppColors.pauseTint)
                    .controlSize(.large)
            }

            Button("Skip", systemImage: "forward.fill", action: onSkip)
                .buttonStyle(.bordered)
                .tint(.secondary)
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
    }
}
