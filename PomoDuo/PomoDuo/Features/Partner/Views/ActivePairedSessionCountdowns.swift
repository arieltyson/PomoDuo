import SwiftUI

struct SessionPhaseBadge: View {
    let session: StudySession
    let hasReachedPhaseEnd: Bool

    var body: some View {
        Label(phaseLabel, systemImage: phaseSymbol)
            .font(.title3)
            .bold()
            .foregroundStyle(phaseColor)
            .padding(.vertical)
            .phaseTransition(phase: phaseLabel)
            .accessibilityAddTraits(.isHeader)
    }

    private var phaseLabel: String {
        switch session.state {
        case .requesting:
            "Waiting for Partner"
        case .focus where session.isPaused:
            "Paused"
        case .focus where hasReachedPhaseEnd:
            "Focus Complete"
        case .focus:
            "Focus"
        case .shortBreak where hasReachedPhaseEnd,
                .longBreak where hasReachedPhaseEnd:
            "Break Complete"
        case .shortBreak:
            "Short Break"
        case .longBreak:
            "Long Break"
        case .completed:
            "Session Complete"
        case .idle:
            "Ready"
        }
    }

    private var phaseSymbol: String {
        switch session.state {
        case .requesting:
            "person.wave.2.fill"
        case .focus where session.isPaused:
            "pause.circle.fill"
        case .focus where hasReachedPhaseEnd:
            "checkmark.circle.fill"
        case .focus:
            "brain.head.profile"
        case .shortBreak where hasReachedPhaseEnd,
                .longBreak where hasReachedPhaseEnd:
            "checkmark.circle.fill"
        case .shortBreak, .longBreak:
            "cup.and.saucer.fill"
        case .completed:
            "checkmark.circle.fill"
        case .idle:
            "circle.fill"
        }
    }

    private var phaseColor: Color {
        switch session.state {
        case .requesting:
            .orange
        case .focus where session.isPaused:
            AppColors.pauseTint
        case .focus where hasReachedPhaseEnd:
            AppColors.success
        case .focus:
            AppColors.lavender
        case .shortBreak where hasReachedPhaseEnd,
                .longBreak where hasReachedPhaseEnd:
            AppColors.success
        case .shortBreak, .longBreak:
            .teal
        case .completed:
            AppColors.success
        case .idle:
            .secondary
        }
    }
}

struct PairedCountdownView: View {
    let session: StudySession
    let hasReachedPhaseEnd: Bool

    var body: some View {
        Group {
            switch session.state {
            case .requesting:
                RequestingCountdownView()
            case .completed:
                CompletedCountdownView()
            default:
                if hasReachedPhaseEnd {
                    ElapsedCountdownView()
                } else if session.isPaused {
                    PausedCountdownView(targetEndDate: session.targetEndDate)
                } else {
                    LiveCountdownView(targetEndDate: session.targetEndDate)
                }
            }
        }
        .accessibilityLabel("Timer")
    }
}

private struct RequestingCountdownView: View {
    var body: some View {
        VStack {
            ProgressView()
                .controlSize(.large)

            Text("Connecting…")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }
}

private struct CompletedCountdownView: View {
    @State private var showCelebration = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack {
            ZStack {
                CelebrationParticlesView(
                    isActive: showCelebration,
                    color: AppColors.lavender
                )

                Image(systemName: "party.popper.fill")
                    .font(.largeTitle)
                    .foregroundStyle(AppColors.lavender)
                    .scaleEffect(showCelebration ? 1 : 0.5)
                    .opacity(showCelebration ? 1 : 0)
            }

            Text("Great work!")
                .font(.title3)
                .foregroundStyle(.secondary)
                .opacity(showCelebration ? 1 : 0)
        }
        .task {
            guard !reduceMotion else {
                showCelebration = true
                return
            }
            withAnimation(.spring(duration: 0.5, bounce: 0.4)) {
                showCelebration = true
            }
        }
    }
}

private struct ElapsedCountdownView: View {
    var body: some View {
        Text("00:00")
            .font(.largeTitle)
            .monospacedDigit()
            .bold()
            .accessibilityValue("00:00")
    }
}

private struct PausedCountdownView: View {
    let targetEndDate: Date

    @State private var breatheOpacity = 1.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(PowerStateMonitor.self) private var powerStateMonitor

    var body: some View {
        Text(remainingText)
            .font(.largeTitle)
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .opacity(breatheOpacity)
            .accessibilityValue(remainingText)
            .task(
                id: AnimationTaskID(
                    reduceMotion: reduceMotion,
                    isLowPowerModeEnabled: powerStateMonitor.isLowPowerModeEnabled
                )
            ) {
                guard !reduceMotion, !powerStateMonitor.isLowPowerModeEnabled else {
                    breatheOpacity = 1.0
                    return
                }
                withAnimation(
                    .easeInOut(duration: 1.5)
                        .repeatForever(autoreverses: true)
                ) {
                    breatheOpacity = 0.4
                }
            }
    }

    private var remainingText: String {
        let remainingSeconds = max(0, Int(targetEndDate.timeIntervalSinceNow))
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60

        let minutesText = minutes < 10 ? "0\(minutes)" : "\(minutes)"
        let secondsText = seconds < 10 ? "0\(seconds)" : "\(seconds)"
        return "\(minutesText):\(secondsText)"
    }

    private struct AnimationTaskID: Equatable {
        let reduceMotion: Bool
        let isLowPowerModeEnabled: Bool
    }
}

private struct LiveCountdownView: View {
    let targetEndDate: Date

    var body: some View {
        Text(
            timerInterval: safeTimerInterval(until: targetEndDate),
            countsDown: true
        )
        .font(.largeTitle)
        .monospacedDigit()
        .bold()
        .contentTransition(.numericText())
    }

    private func safeTimerInterval(until targetEndDate: Date) -> ClosedRange<Date> {
        let now = Date.now
        return now...max(now, targetEndDate)
    }
}

struct PairedRoundProgress: View {
    let currentRound: Int
    let totalRounds: Int

    var body: some View {
        HStack {
            ForEach(1...max(1, totalRounds), id: \.self) { round in
                RoundStatusDot(
                    isCompleted: round < currentRound,
                    isCurrent: round == currentRound
                )
            }
        }
        .padding(.top)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Round \(currentRound) of \(totalRounds)")
    }
}

private struct RoundStatusDot: View {
    let isCompleted: Bool
    let isCurrent: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle()
                .fill(fillColor)
                .frame(width: 12, height: 12)

            if isCompleted {
                Image(systemName: "checkmark")
                    .font(.system(size: 6, weight: .bold))
                    .foregroundStyle(.white)
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .scale.combined(with: .opacity)
                    )
            }

            if isCurrent {
                Circle()
                    .stroke(AppColors.lavender, lineWidth: 2)
                    .frame(width: 18, height: 18)
            }
        }
        .roundCompletionPop(isCompleted: isCompleted)
        .animation(
            reduceMotion ? .none : .spring(duration: 0.4, bounce: 0.3),
            value: isCompleted
        )
    }

    private var fillColor: Color {
        if isCompleted {
            return AppColors.lavender
        }

        if isCurrent {
            return AppColors.lavender.opacity(0.45)
        }

        return .secondary.opacity(0.3)
    }
}
