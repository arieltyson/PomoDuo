import SwiftData
import SwiftUI

/// Main solo timer screen.
struct TimerView: View {
    @Query private var configurations: [TimerConfiguration]
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthManager.self) private var authManager
    @Environment(NotificationManager.self) private var notificationManager
    @Environment(LiveActivityManager.self) private var liveActivityManager
    @Environment(FocusIntentState.self) private var focusIntentState
    @Environment(RestrictionCoordinator.self) private var restrictionCoordinator
    @Environment(PowerStateMonitor.self) private var powerStateMonitor
    @Environment(\.scenePhase) private var scenePhase

    @State private var activeConfiguration: TimerConfiguration?
    @State private var viewModel = TimerViewModel()
    @State private var currentRound = 1
    @State private var phase: TimerPhase = .idle
    @State private var haptic = HapticTrigger()
    @State private var focusStartedAt: Date?
    @State private var lockScreenPulsePhase = false

    var body: some View {
        Group {
            if let activeConfiguration {
                TimerCanvasView(
                    phaseName: phaseName(
                        for: phase,
                        isRunning: viewModel.isRunning,
                        isComplete: viewModel.isComplete
                    ),
                    currentRound: currentRound,
                    totalRounds: activeConfiguration.roundsBeforeLongBreak,
                    remainingProgress: remainingProgress(
                        from: viewModel.currentTick
                    ),
                    timeString: timeString(
                        currentTick: viewModel.currentTick,
                        phase: phase,
                        configuration: activeConfiguration
                    ),
                    isPaused: viewModel.currentTick?.isPaused ?? false,
                    isBreak: phase.isBreak,
                    isRunning: viewModel.isRunning,
                    isComplete: viewModel.isComplete,
                    isBlocking: restrictionCoordinator.isRestricting,
                    onStart: { startFocus(using: activeConfiguration) },
                    onPause: pauseTimer,
                    onResume: resumeTimer,
                    onStop: stopTimer,
                    onSkip: { advancePhase(using: activeConfiguration) }
                )
            } else {
                TimerConfigurationLoadingView()
            }
        }
        .sensoryFeedback(haptic.feedback, trigger: haptic)
        .onAppear {
            updateIdleTimer(isDisabled: viewModel.isRunning)
        }
        .onChange(of: viewModel.isRunning) { _, isRunning in
            updateIdleTimer(isDisabled: isRunning)
        }
        .onChange(of: viewModel.isComplete) { wasComplete, isNowComplete in
            if !wasComplete && isNowComplete {
                haptic.fire(.complete)
                liveActivityManager.end()
                recordCompletedFocusIfNeeded()
                restrictionCoordinator.liftRestrictions()
                AccessibilityAnnouncer.announceRoundComplete()
            }
        }
        .onChange(of: viewModel.currentTick) { previousTick, currentTick in
            syncLockScreenPulse(previousTick: previousTick, currentTick: currentTick)
        }
        .onChange(of: focusIntentState.pendingFocusRequest) { _, isPending in
            if isPending {
                consumePendingFocusRequest()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                processLiveActivityBridgeCommands()
            }
        }
        .navigationTitle("Focus")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: configurations.count) {
            await ensureConfigurationLoaded()
        }
        .onDisappear {
            updateIdleTimer(isDisabled: false)
        }
    }

    private func updateIdleTimer(isDisabled: Bool) {
        UIApplication.shared.isIdleTimerDisabled = isDisabled
    }

    private func consumePendingFocusRequest() {
        guard focusIntentState.consumeStartFocusRequest(),
            !viewModel.isRunning,
            let configuration = activeConfiguration
        else {
            return
        }

        startFocus(using: configuration)
    }

    /// Reads and processes any pending command written by a Live Activity intent.
    ///
    /// Called when the app transitions to `.active` so that Pause / Resume / Stop
    /// actions triggered from the Dynamic Island are reflected in the app's state.
    private func processLiveActivityBridgeCommands() {
        guard let pending = LiveActivityBridge.read() else { return }
        defer { LiveActivityBridge.clear() }

        // Ignore stale commands (older than 60 seconds).
        guard Date.now.timeIntervalSince(pending.timestamp) < 60 else { return }

        switch pending.command {
        case .pause:
            if viewModel.isRunning
                && !(viewModel.currentTick?.isPaused ?? true)
            {
                pauseTimer()
            }
        case .resume:
            if viewModel.isRunning
                && (viewModel.currentTick?.isPaused ?? false)
            {
                resumeTimer()
            }
        case .stop:
            if viewModel.isRunning {
                stopTimer()
            }
        }
    }

    @MainActor
    private func ensureConfigurationLoaded() async {
        if let existing = configurations.first {
            activeConfiguration = existing
        } else if activeConfiguration == nil {
            let configuration = TimerConfiguration()
            modelContext.insert(configuration)
            activeConfiguration = configuration
        }

        consumePendingFocusRequest()
    }

    private func startFocus(using configuration: TimerConfiguration) {
        lockScreenPulsePhase = false
        phase = .focus
        focusStartedAt = .now
        viewModel.startFocus(with: configuration)
        haptic.fire(.start)

        let targetEndDate = Date.now.addingTimeInterval(
            configuration.focusDuration
        )
        liveActivityManager.start(
            phase: .focus,
            currentRound: currentRound,
            totalRounds: configuration.roundsBeforeLongBreak,
            targetEndDate: targetEndDate,
            phaseDuration: configuration.focusDuration
        )

        scheduleNotification(
            duration: configuration.focusDuration,
            message: "Focus session complete! Time for a break. 🎉"
        )

        restrictionCoordinator.enforceFocusRestrictions()

        AccessibilityAnnouncer.announceStart(
            round: currentRound,
            totalRounds: configuration.roundsBeforeLongBreak
        )
    }

    private func pauseTimer() {
        let remainingSeconds = max(
            0,
            viewModel.currentTick?.remainingSeconds ?? 0
        )
        lockScreenPulsePhase = false
        viewModel.pause()
        haptic.fire(.pause)
        liveActivityManager.update(
            phase: phase.activityPhase,
            currentRound: currentRound,
            targetEndDate: .now.addingTimeInterval(remainingSeconds),
            isPaused: true,
            phaseDuration: phaseDuration(for: phase),
            pausedRemainingSeconds: remainingSeconds,
            pulsePhase: false
        )
        cancelNotification()
        AccessibilityAnnouncer.announcePause()
    }

    private func resumeTimer() {
        let remainingSeconds = max(
            0,
            viewModel.currentTick?.remainingSeconds ?? 0
        )
        lockScreenPulsePhase = false
        viewModel.unpause()
        haptic.fire(.resume)

        guard remainingSeconds > 0 else {
            liveActivityManager.end()
            return
        }

        let targetEndDate = Date.now.addingTimeInterval(remainingSeconds)
        liveActivityManager.update(
            phase: phase.activityPhase,
            currentRound: currentRound,
            targetEndDate: targetEndDate,
            isPaused: false,
            phaseDuration: phaseDuration(for: phase),
            pulsePhase: false
        )

        let message =
            phase.isBreak
            ? "Break's over! Ready to focus? 📚"
            : "Focus session complete! Time for a break. 🎉"
        scheduleNotification(duration: remainingSeconds, message: message)
        AccessibilityAnnouncer.announceResume()
    }

    private func stopTimer() {
        lockScreenPulsePhase = false
        viewModel.stop()
        phase = .idle
        currentRound = 1
        focusStartedAt = nil
        haptic.fire(.stop)
        liveActivityManager.end()
        cancelNotification()
        restrictionCoordinator.forceRemoveRestrictions()
        AccessibilityAnnouncer.announceStop()
    }

    private func advancePhase(using configuration: TimerConfiguration) {
        haptic.fire(.phaseChange)
        lockScreenPulsePhase = false

        switch phase {
        case .idle, .focus:
            focusStartedAt = nil
            restrictionCoordinator.liftRestrictions()
            if currentRound >= configuration.roundsBeforeLongBreak {
                phase = .longBreak
                viewModel.startLongBreak(with: configuration)

                let targetEndDate = Date.now.addingTimeInterval(
                    configuration.longBreakDuration
                )
                liveActivityManager.start(
                    phase: .longBreak,
                    currentRound: currentRound,
                    totalRounds: configuration.roundsBeforeLongBreak,
                    targetEndDate: targetEndDate,
                    phaseDuration: configuration.longBreakDuration
                )

                scheduleNotification(
                    duration: configuration.longBreakDuration,
                    message: "Long break is over! Ready for another round? 💪"
                )
                AccessibilityAnnouncer.announceBreakStarted(isLong: true)
            } else {
                phase = .shortBreak
                viewModel.startShortBreak(with: configuration)

                let targetEndDate = Date.now.addingTimeInterval(
                    configuration.shortBreakDuration
                )
                liveActivityManager.start(
                    phase: .shortBreak,
                    currentRound: currentRound,
                    totalRounds: configuration.roundsBeforeLongBreak,
                    targetEndDate: targetEndDate,
                    phaseDuration: configuration.shortBreakDuration
                )

                scheduleNotification(
                    duration: configuration.shortBreakDuration,
                    message: "Break's over! Ready to focus? 📚"
                )
                AccessibilityAnnouncer.announceBreakStarted(isLong: false)
            }
        case .shortBreak:
            currentRound += 1
            phase = .focus
            focusStartedAt = .now
            viewModel.startFocus(with: configuration)

            let targetEndDate = Date.now.addingTimeInterval(
                configuration.focusDuration
            )
            liveActivityManager.start(
                phase: .focus,
                currentRound: currentRound,
                totalRounds: configuration.roundsBeforeLongBreak,
                targetEndDate: targetEndDate,
                phaseDuration: configuration.focusDuration
            )

            scheduleNotification(
                duration: configuration.focusDuration,
                message: "Focus session complete! Time for a break. 🎉"
            )

            restrictionCoordinator.enforceFocusRestrictions()

            AccessibilityAnnouncer.announceFocusResumed(
                round: currentRound,
                totalRounds: configuration.roundsBeforeLongBreak
            )
        case .longBreak:
            currentRound = 1
            phase = .focus
            focusStartedAt = .now
            viewModel.startFocus(with: configuration)

            let targetEndDate = Date.now.addingTimeInterval(
                configuration.focusDuration
            )
            liveActivityManager.start(
                phase: .focus,
                currentRound: currentRound,
                totalRounds: configuration.roundsBeforeLongBreak,
                targetEndDate: targetEndDate,
                phaseDuration: configuration.focusDuration
            )

            scheduleNotification(
                duration: configuration.focusDuration,
                message: "Focus session complete! Time for a break. 🎉"
            )

            restrictionCoordinator.enforceFocusRestrictions()

            AccessibilityAnnouncer.announceFocusResumed(
                round: currentRound,
                totalRounds: configuration.roundsBeforeLongBreak
            )
        }
    }

    private func recordCompletedFocusIfNeeded() {
        guard phase == .focus,
            let configuration = activeConfiguration,
            let startedAt = focusStartedAt
        else {
            return
        }

        let session = CompletedSession(
            startedAt: startedAt,
            focusDuration: configuration.focusDuration,
            roundNumber: currentRound,
            totalRounds: configuration.roundsBeforeLongBreak,
            sessionType: .solo,
            userID: authManager.currentUserID
        )

        modelContext.insert(session)
        focusStartedAt = nil
        refreshWidgetData()
    }

    private func refreshWidgetData() {
        let descriptor = FetchDescriptor<CompletedSession>(
            sortBy: [SortDescriptor(\.dayBucket, order: .reverse)]
        )
        guard let sessions = try? modelContext.fetch(descriptor) else { return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let scopedSessions = sessionsForCurrentUser(from: sessions)
        let todaySessions = scopedSessions.filter {
            calendar.isDate($0.dayBucket, inSameDayAs: today)
        }
        let todayMinutes = todaySessions.reduce(0) { $0 + $1.focusMinutes }
        let todaySessionCount = todaySessions.count
        let currentStreak = streakCount(
            from: scopedSessions.map(\.dayBucket),
            calendar: calendar,
            today: today
        )

        WidgetDataProvider.update(
            todayMinutes: todayMinutes,
            todaySessionCount: todaySessionCount,
            currentStreak: currentStreak
        )
        WidgetDataProvider.reloadWidget()
    }

    private func sessionsForCurrentUser(from sessions: [CompletedSession])
        -> [CompletedSession]
    {
        guard let userID = authManager.currentUserID else { return sessions }
        return sessions.filter { $0.userID == nil || $0.userID == userID }
    }

    private func streakCount(
        from dayBuckets: [Date],
        calendar: Calendar,
        today: Date
    ) -> Int {
        let activeDays = Set(dayBuckets.map { calendar.startOfDay(for: $0) })
        var cursor = today
        var streak = 0

        while activeDays.contains(cursor) {
            streak += 1
            guard
                let previous = calendar.date(
                    byAdding: .day,
                    value: -1,
                    to: cursor
                )
            else {
                break
            }
            cursor = previous
        }

        return streak
    }

    private func scheduleNotification(duration: TimeInterval, message: String) {
        Task {
            if !notificationManager.hasCheckedAuthorization
                || !notificationManager.isAuthorized
            {
                await notificationManager.requestPermission()
            }

            guard notificationManager.isAuthorized else { return }

            let endDate = Date.now.addingTimeInterval(max(1, duration))
            await notificationManager.scheduleTimerEnd(
                at: endDate,
                message: message
            )
        }
    }

    private func cancelNotification() {
        Task {
            await notificationManager.cancelTimerEnd()
        }
    }

    private func phaseName(
        for phase: TimerPhase,
        isRunning: Bool,
        isComplete: Bool
    ) -> String {
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

    private func phaseDuration(for phase: TimerPhase) -> TimeInterval {
        guard let configuration = activeConfiguration else { return 0 }
        switch phase {
        case .idle, .focus:
            return configuration.focusDuration
        case .shortBreak:
            return configuration.shortBreakDuration
        case .longBreak:
            return configuration.longBreakDuration
        }
    }

    /// Updates a lightweight pulse token for lock-screen Live Activity icon motion.
    ///
    /// Live Activities don't reliably run arbitrary continuous animations.
    /// Toggling this token through content updates gives the system concrete
    /// state changes it can render even in constrained lock-screen contexts.
    private func syncLockScreenPulse(
        previousTick: TimerTick?,
        currentTick: TimerTick?
    ) {
        guard viewModel.isRunning,
            let currentTick,
            !currentTick.isPaused,
            phase == .focus,
            liveActivityManager.isActivityActive
        else {
            return
        }

        let oldWholeSeconds = previousTick.map {
            Int(max(0, $0.remainingSeconds).rounded(.down))
        }
        let newWholeSeconds = Int(max(0, currentTick.remainingSeconds).rounded(.down))

        guard oldWholeSeconds != newWholeSeconds else { return }
        guard newWholeSeconds > 0 else { return }
        let pulseIntervalSeconds = powerStateMonitor.isLowPowerModeEnabled ? 30 : 5
        guard newWholeSeconds.isMultiple(of: pulseIntervalSeconds) else { return }

        lockScreenPulsePhase.toggle()

        liveActivityManager.update(
            phase: phase.activityPhase,
            currentRound: currentRound,
            targetEndDate: .now.addingTimeInterval(currentTick.remainingSeconds),
            isPaused: false,
            phaseDuration: phaseDuration(for: phase),
            pulsePhase: lockScreenPulsePhase
        )
    }

    private func idleTimeString(
        for phase: TimerPhase,
        configuration: TimerConfiguration
    ) -> String {
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
        let minutesText =
            minutesPart < 10 ? "0\(minutesPart)" : "\(minutesPart)"
        let secondsText =
            secondsPart < 10 ? "0\(secondsPart)" : "\(secondsPart)"
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
    let isBlocking: Bool

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
                totalRounds: totalRounds,
                isRunning: isRunning,
                isComplete: isComplete,
                onPause: onPause,
                onResume: onResume,
                onStop: onStop,
                onSkip: onSkip
            )

            Spacer()

            VStack {
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

                if isBlocking {
                    BlockingIndicatorView()
                }
            }
            .padding(.bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            Rectangle()
                .fill(.background)
                .ignoresSafeArea()
        }
    }
}

private struct BlockingIndicatorView: View {
    var body: some View {
        Label("Apps Blocked", systemImage: "shield.fill")
            .font(.caption2)
            .foregroundStyle(AppColors.lavender)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(AppColors.lavender.opacity(0.14), in: .capsule)
            .accessibilityLabel("App blocking is active")
            .transition(.opacity)
    }
}

private struct TimerBodyContent: View {
    let remainingProgress: Double
    let timeString: String
    let isPaused: Bool
    let isBreak: Bool
    let currentRound: Int
    let totalRounds: Int
    let isRunning: Bool
    let isComplete: Bool

    let onPause: () -> Void
    let onResume: () -> Void
    let onStop: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack {
            ZStack {
                CircularProgressView(
                    remainingProgress: remainingProgress,
                    timeString: timeString,
                    isPaused: isPaused,
                    isBreak: isBreak
                )

                CelebrationParticlesView(
                    isActive: isComplete,
                    color: isBreak ? AppColors.breakTint : AppColors.lavender
                )
            }
            .containerRelativeFrame(.horizontal) { width, _ in
                width * 0.66
            }
            .accessibilityActions {
                if isRunning && !isComplete {
                    if isPaused {
                        Button("Resume", action: onResume)
                    } else {
                        Button("Pause", action: onPause)
                    }
                    Button("Stop", action: onStop)
                }

                if isComplete {
                    Button("Continue", action: onSkip)
                }
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

    var activityPhase: TimerActivityAttributes.Phase {
        switch self {
        case .idle, .focus:
            .focus
        case .shortBreak:
            .shortBreak
        case .longBreak:
            .longBreak
        }
    }
}
