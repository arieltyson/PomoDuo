//
//  TimerView.swift
//  PomoDuo
//
//  Created by Codex on 2/15/26.
//

import SwiftUI
import SwiftData

/// Main solo timer screen.
struct TimerView: View {
    @Query private var configurations: [TimerConfiguration]
    @Environment(\.modelContext) private var modelContext

    @State private var activeConfiguration: TimerConfiguration?
    @State private var viewModel = TimerViewModel()
    @State private var currentRound = 1
    @State private var phase: TimerPhase = .idle

    var body: some View {
        Group {
            if let activeConfiguration {
                TimerCanvasView(
                    phaseName: phaseName(for: phase, isRunning: viewModel.isRunning, isComplete: viewModel.isComplete),
                    currentRound: currentRound,
                    totalRounds: activeConfiguration.roundsBeforeLongBreak,
                    remainingProgress: remainingProgress(from: viewModel.currentTick),
                    timeString: timeString(
                        currentTick: viewModel.currentTick,
                        phase: phase,
                        configuration: activeConfiguration
                    ),
                    isPaused: viewModel.currentTick?.isPaused ?? false,
                    isBreak: phase.isBreak,
                    isRunning: viewModel.isRunning,
                    isComplete: viewModel.isComplete,
                    onStart: { startFocus(using: activeConfiguration) },
                    onPause: { viewModel.pause() },
                    onResume: { viewModel.unpause() },
                    onStop: stopTimer,
                    onSkip: { advancePhase(using: activeConfiguration) }
                )
            } else {
                TimerConfigurationLoadingView()
            }
        }
        .navigationTitle("Focus")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: configurations.count) {
            await ensureConfigurationLoaded()
        }
    }

    @MainActor
    private func ensureConfigurationLoaded() async {
        if let existing = configurations.first {
            activeConfiguration = existing
            return
        }

        guard activeConfiguration == nil else { return }

        let configuration = TimerConfiguration()
        modelContext.insert(configuration)
        activeConfiguration = configuration
    }

    private func startFocus(using configuration: TimerConfiguration) {
        phase = .focus
        viewModel.startFocus(with: configuration)
    }

    private func stopTimer() {
        viewModel.stop()
        phase = .idle
        currentRound = 1
    }

    private func advancePhase(using configuration: TimerConfiguration) {
        switch phase {
        case .idle, .focus:
            if currentRound >= configuration.roundsBeforeLongBreak {
                phase = .longBreak
                viewModel.startLongBreak(with: configuration)
            } else {
                phase = .shortBreak
                viewModel.startShortBreak(with: configuration)
            }
        case .shortBreak:
            currentRound += 1
            phase = .focus
            viewModel.startFocus(with: configuration)
        case .longBreak:
            currentRound = 1
            phase = .focus
            viewModel.startFocus(with: configuration)
        }
    }

    private func phaseName(for phase: TimerPhase, isRunning: Bool, isComplete: Bool) -> String {
        if !isRunning && !isComplete && phase == .idle {
            return "Ready"
        }
        return phase.title
    }

    private func remainingProgress(from currentTick: TimerTick?) -> Double {
        guard let currentTick else { return 1 }
        return 1 - currentTick.progress
    }

    private func timeString(
        currentTick: TimerTick?,
        phase: TimerPhase,
        configuration: TimerConfiguration
    ) -> String {
        if let currentTick {
            return currentTick.formattedTime
        }
        return idleTimeString(for: phase, configuration: configuration)
    }

    private func idleTimeString(for phase: TimerPhase, configuration: TimerConfiguration) -> String {
        switch phase {
        case .idle, .focus:
            return formattedClock(configuration.focusDuration)
        case .shortBreak:
            return formattedClock(configuration.shortBreakDuration)
        case .longBreak:
            return formattedClock(configuration.longBreakDuration)
        }
    }

    private func formattedClock(_ duration: TimeInterval) -> String {
        let seconds = max(0, Int(duration))
        let minutesPart = seconds / 60
        let secondsPart = seconds % 60
        let minutesText = minutesPart < 10 ? "0\(minutesPart)" : "\(minutesPart)"
        let secondsText = secondsPart < 10 ? "0\(secondsPart)" : "\(secondsPart)"
        return "\(minutesText):\(secondsText)"
    }
}

private struct TimerCanvasView: View {
    let phaseName: String
    let currentRound: Int
    let totalRounds: Int

    let remainingProgress: Double
    let timeString: String
    let isPaused: Bool
    let isBreak: Bool

    let isRunning: Bool
    let isComplete: Bool

    let onStart: () -> Void
    let onPause: () -> Void
    let onResume: () -> Void
    let onStop: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            SessionHeaderView(
                phaseName: phaseName,
                currentRound: currentRound,
                totalRounds: totalRounds
            )

            Rectangle()
                .fill(AppGradients.bannerFade)
                .frame(height: 40)

            Spacer()

            TimerBodyContent(
                remainingProgress: remainingProgress,
                timeString: timeString,
                isPaused: isPaused,
                isBreak: isBreak,
                currentRound: currentRound,
                totalRounds: totalRounds
            )

            Spacer()

            TimerControlsView(
                isRunning: isRunning,
                isPaused: isPaused,
                isComplete: isComplete,
                onStart: onStart,
                onPause: onPause,
                onResume: onResume,
                onStop: onStop,
                onSkip: onSkip
            )
            .padding(.bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.surface.ignoresSafeArea())
    }
}

private struct TimerBodyContent: View {
    let remainingProgress: Double
    let timeString: String
    let isPaused: Bool
    let isBreak: Bool
    let currentRound: Int
    let totalRounds: Int

    var body: some View {
        VStack {
            CircularProgressView(
                remainingProgress: remainingProgress,
                timeString: timeString,
                isPaused: isPaused,
                isBreak: isBreak
            )
            .containerRelativeFrame(.horizontal) { width, _ in
                width * 0.66
            }

            RoundIndicatorView(
                currentRound: currentRound,
                totalRounds: totalRounds
            )
            .padding(.top)
        }
    }
}

private struct TimerConfigurationLoadingView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Timer", systemImage: "timer")
        } description: {
            Text("Preparing your focus setup.")
        }
    }
}

private enum TimerPhase {
    case idle
    case focus
    case shortBreak
    case longBreak

    var isBreak: Bool {
        switch self {
        case .shortBreak, .longBreak:
            true
        case .idle, .focus:
            false
        }
    }

    var title: String {
        switch self {
        case .idle:
            "Ready"
        case .focus:
            "Focus"
        case .shortBreak:
            "Short Break"
        case .longBreak:
            "Long Break"
        }
    }
}
