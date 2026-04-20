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
    @Environment(FocusStatsReporter.self) private var focusStatsReporter
    @Environment(SessionManager.self) private var sessionManager
    @Environment(\.scenePhase) private var scenePhase

    @State private var activeConfiguration: TimerConfiguration?
    @State private var viewModel = TimerViewModel()
    @State private var currentRound = 1
    @State private var phase: TimerPhase = .idle
    @State private var haptic = HapticTrigger()
    @State private var focusStartedAt: Date?
    @State private var suppressNextCompletionHandling = false
    @State private var isShowingPairedSessionConflict = false

    private let sessionStore = SoloTimerSessionStore()

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
                    isBlockingActive: restrictionCoordinator.isRestricting,
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
                if suppressNextCompletionHandling {
                    suppressNextCompletionHandling = false
                    return
                }
                handleForegroundPhaseCompletion()
            }
        }
        .onChange(of: focusIntentState.pendingFocusRequest) { _, isPending in
            if isPending {
                consumePendingFocusRequest()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                _ = processLiveActivityBridgeCommands()
                syncTimerStateFromPersistence()
            }
        }
        .navigationTitle("Focus")
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            "Partner Session Active",
            isPresented: $isShowingPairedSessionConflict
        ) {
            Button("OK") {}
        } message: {
            Text("You have a paired session running on the Partner tab. End it before starting a solo focus session.")
        }
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
            !sessionManager.hasActivePairedSession,
            let configuration = activeConfiguration
        else {
            return
        }

        startFocus(using: configuration)
    }

    /// Reads and processes any pending command written by a Live Activity intent.
    ///
    /// Called when the app transitions to `.active` and on timer ticks so that
    /// Pause / Resume / Stop actions triggered from the Dynamic Island are
    /// reflected in the app's state before any local timer side effects run.
    private func processLiveActivityBridgeCommands() -> Bool {
        guard let pending = LiveActivityBridge.read() else { return false }
        defer { LiveActivityBridge.clear() }

        // Ignore stale commands (older than 60 seconds).
        guard Date.now.timeIntervalSince(pending.timestamp) < 60 else {
            return true
        }

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

        return true
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
        syncTimerStateFromPersistence()
    }

    private func startFocus(using configuration: TimerConfiguration) {
        guard !sessionManager.hasActivePairedSession else {
            isShowingPairedSessionConflict = true
            return
        }

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
        persistSession(
            status: .running,
            targetEndDate: targetEndDate,
            phaseDuration: configuration.focusDuration
        )

        restrictionCoordinator.enforceFocusRestrictions(until: targetEndDate)

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
        viewModel.pause()
        haptic.fire(.pause)
        liveActivityManager.update(
            phase: phase.activityPhase,
            currentRound: currentRound,
            targetEndDate: .now.addingTimeInterval(remainingSeconds),
            isPaused: true,
            phaseDuration: phaseDuration(for: phase),
            pausedRemainingSeconds: remainingSeconds
        )
        persistSession(
            status: .paused,
            targetEndDate: .now.addingTimeInterval(remainingSeconds),
            phaseDuration: phaseDuration(for: phase),
            pausedRemainingSeconds: remainingSeconds
        )
        cancelNotification()
        AccessibilityAnnouncer.announcePause()
    }

    private func resumeTimer() {
        let remainingSeconds = max(
            0,
            viewModel.currentTick?.remainingSeconds ?? 0
        )
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
            phaseDuration: phaseDuration(for: phase)
        )

        let message =
            phase.isBreak
            ? "Break's over! Ready to focus? 📚"
            : "Focus session complete! Time for a break. 🎉"
        scheduleNotification(duration: remainingSeconds, message: message)
        persistSession(
            status: .running,
            targetEndDate: targetEndDate,
            phaseDuration: phaseDuration(for: phase)
        )
        AccessibilityAnnouncer.announceResume()
    }

    private func stopTimer() {
        recordPartialFocusIfNeeded()
        viewModel.stop()
        phase = .idle
        currentRound = 1
        focusStartedAt = nil
        haptic.fire(.stop)
        liveActivityManager.end()
        clearPersistedSession()
        cancelNotification()
        restrictionCoordinator.forceRemoveRestrictions()
        AccessibilityAnnouncer.announceStop()
    }

    private func advancePhase(using configuration: TimerConfiguration) {
        haptic.fire(.phaseChange)

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
                persistSession(
                    status: .running,
                    targetEndDate: targetEndDate,
                    phaseDuration: configuration.longBreakDuration
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
                persistSession(
                    status: .running,
                    targetEndDate: targetEndDate,
                    phaseDuration: configuration.shortBreakDuration
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
            persistSession(
                status: .running,
                targetEndDate: targetEndDate,
                phaseDuration: configuration.focusDuration
            )

            restrictionCoordinator.enforceFocusRestrictions(until: targetEndDate)

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
            persistSession(
                status: .running,
                targetEndDate: targetEndDate,
                phaseDuration: configuration.focusDuration
            )

            restrictionCoordinator.enforceFocusRestrictions(until: targetEndDate)

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

        let elapsed = Date.now.timeIntervalSince(startedAt)
        let focusDuration = min(elapsed, configuration.focusDuration)
        guard focusDuration >= 60 else { return }

        let session = CompletedSession(
            startedAt: startedAt,
            focusDuration: focusDuration,
            roundNumber: currentRound,
            totalRounds: configuration.roundsBeforeLongBreak,
            sessionType: .solo,
            userID: authManager.currentUserID
        )

        modelContext.insert(session)
        focusStatsReporter.report(focusMinutes: session.focusMinutes)
        focusStartedAt = nil
        refreshWidgetData()
    }

    /// Records a partial focus round when the user ends a session early.
    ///
    /// Only records if at least 60 seconds of focus elapsed, preventing
    /// accidental taps from inflating totals.
    private func recordPartialFocusIfNeeded() {
        guard phase == .focus,
            let startedAt = focusStartedAt
        else {
            return
        }

        let elapsed = Date.now.timeIntervalSince(startedAt)
        guard elapsed >= 60 else { return }

        let session = CompletedSession(
            startedAt: startedAt,
            focusDuration: elapsed,
            roundNumber: currentRound,
            totalRounds: activeConfiguration?.roundsBeforeLongBreak ?? 4,
            sessionType: .solo,
            userID: authManager.currentUserID
        )

        modelContext.insert(session)
        focusStatsReporter.report(focusMinutes: session.focusMinutes)
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

    private func handleForegroundPhaseCompletion() {
        haptic.fire(.complete)
        liveActivityManager.end()
        recordCompletedFocusIfNeeded()
        persistSession(
            status: .awaitingContinuation,
            targetEndDate: .now,
            phaseDuration: phaseDuration(for: phase)
        )
        cancelNotification()
        restrictionCoordinator.liftRestrictions()
        AccessibilityAnnouncer.announceRoundComplete()
    }

    private func syncTimerStateFromPersistence() {
        guard activeConfiguration != nil, let snapshot = sessionStore.load() else {
            return
        }

        // A paired session takes precedence — discard any stale solo state
        // rather than restoring it into a conflicting dual-session scenario.
        guard !sessionManager.hasActivePairedSession else {
            clearPersistedSession()
            return
        }

        if snapshot.status == .running && snapshot.targetEndDate <= .now {
            restoreAwaitingContinuation(from: snapshot)
            return
        }

        switch snapshot.status {
        case .running:
            if isDisplayingRunningSnapshot(snapshot) {
                // UI already matches persistence — but the Screen Time
                // pipeline underneath may have degraded while the app was
                // backgrounded (Monitor schedule dropped, App-Group
                // session context cleared by an extension cleanup pass,
                // shield channels reset). Reconcile is idempotent and
                // converges the pipeline back to the canonical "active
                // focus" state without disturbing the visible UI.
                if snapshot.phase == .focus {
                    restrictionCoordinator.reconcileFocusRestrictions(
                        until: snapshot.targetEndDate
                    )
                }
                return
            }
            restoreRunning(from: snapshot)
        case .paused:
            guard !isDisplayingPausedSnapshot(snapshot) else {
                return
            }
            restorePaused(from: snapshot)
        case .awaitingContinuation:
            guard !isDisplayingAwaitingContinuation(snapshot) else {
                return
            }
            restoreAwaitingContinuation(from: snapshot)
        }
    }

    private func restoreRunning(from snapshot: SoloTimerSessionSnapshot) {
        phase = snapshot.phase
        currentRound = snapshot.currentRound
        focusStartedAt = snapshot.focusStartedAt
        viewModel.syncToRemote(
            targetEndDate: snapshot.targetEndDate,
            totalDuration: snapshot.phaseDuration
        )
        liveActivityManager.start(
            phase: snapshot.phase.activityPhase,
            currentRound: snapshot.currentRound,
            totalRounds: activeConfiguration?.roundsBeforeLongBreak ?? 4,
            targetEndDate: snapshot.targetEndDate,
            phaseDuration: snapshot.phaseDuration
        )

        if snapshot.phase == .focus {
            // Use reconcile (no `!isRestricting` short-circuit) so a
            // restore that lands while the coordinator already believes
            // it's restricting still rewrites shields + session context
            // + monitoring. Avoids the previous gap where post-crash
            // restores left the pipeline degraded.
            restrictionCoordinator.reconcileFocusRestrictions(
                until: snapshot.targetEndDate
            )
        } else {
            restrictionCoordinator.liftRestrictions()
        }
    }

    private func restorePaused(from snapshot: SoloTimerSessionSnapshot) {
        let pausedTargetEndDate = Date.now.addingTimeInterval(
            snapshot.pausedRemainingSeconds
        )

        phase = snapshot.phase
        currentRound = snapshot.currentRound
        focusStartedAt = snapshot.focusStartedAt
        viewModel.restorePaused(
            remainingSeconds: snapshot.pausedRemainingSeconds,
            totalDuration: snapshot.phaseDuration
        )
        liveActivityManager.start(
            phase: snapshot.phase.activityPhase,
            currentRound: snapshot.currentRound,
            totalRounds: activeConfiguration?.roundsBeforeLongBreak ?? 4,
            targetEndDate: pausedTargetEndDate,
            phaseDuration: snapshot.phaseDuration
        )
        liveActivityManager.update(
            phase: snapshot.phase.activityPhase,
            currentRound: snapshot.currentRound,
            targetEndDate: pausedTargetEndDate,
            isPaused: true,
            phaseDuration: snapshot.phaseDuration,
            pausedRemainingSeconds: snapshot.pausedRemainingSeconds
        )
        cancelNotification()
        restrictionCoordinator.liftRestrictions()
    }

    private func restoreAwaitingContinuation(
        from snapshot: SoloTimerSessionSnapshot
    ) {
        phase = snapshot.phase
        currentRound = snapshot.currentRound
        focusStartedAt = snapshot.focusStartedAt
        suppressNextCompletionHandling = true
        viewModel.restoreCompleted(totalDuration: snapshot.phaseDuration)
        liveActivityManager.end()
        recordCompletedFocusIfNeeded()
        persistSession(
            status: .awaitingContinuation,
            targetEndDate: snapshot.targetEndDate,
            phaseDuration: snapshot.phaseDuration
        )
        cancelNotification()
        restrictionCoordinator.liftRestrictions()
    }

    private func persistSession(
        status: SoloTimerSessionSnapshot.Status,
        targetEndDate: Date,
        phaseDuration: TimeInterval,
        pausedRemainingSeconds: TimeInterval = 0
    ) {
        guard phase != .idle else {
            clearPersistedSession()
            return
        }

        sessionStore.save(
            SoloTimerSessionSnapshot(
                phase: phase,
                currentRound: currentRound,
                focusStartedAt: focusStartedAt,
                targetEndDate: targetEndDate,
                phaseDuration: phaseDuration,
                status: status,
                pausedRemainingSeconds: pausedRemainingSeconds
            )
        )
    }

    private func clearPersistedSession() {
        sessionStore.clear()
    }

    private func isDisplayingRunningSnapshot(
        _ snapshot: SoloTimerSessionSnapshot
    ) -> Bool {
        viewModel.isRunning
            && !viewModel.isComplete
            && !(viewModel.currentTick?.isPaused ?? false)
            && phase == snapshot.phase
            && currentRound == snapshot.currentRound
    }

    private func isDisplayingPausedSnapshot(
        _ snapshot: SoloTimerSessionSnapshot
    ) -> Bool {
        viewModel.isRunning
            && !viewModel.isComplete
            && (viewModel.currentTick?.isPaused ?? false)
            && phase == snapshot.phase
            && currentRound == snapshot.currentRound
    }

    private func isDisplayingAwaitingContinuation(
        _ snapshot: SoloTimerSessionSnapshot
    ) -> Bool {
        !viewModel.isRunning
            && viewModel.isComplete
            && phase == snapshot.phase
            && currentRound == snapshot.currentRound
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
        if viewModel.isComplete { return 0 }
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
    let isBlockingActive: Bool

    let onStart: () -> Void
    let onPause: () -> Void
    let onResume: () -> Void
    let onStop: () -> Void
    let onSkip: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            SessionHeaderView(
                phaseName: phaseName,
                currentRound: currentRound,
                totalRounds: totalRounds
            )

            Rectangle()
                .fill(AppGradients.bannerFade(for: colorScheme))
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            TimerControlDock(isBlockingActive: isBlockingActive) {
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
            }
        }
        .background {
            Rectangle()
                .fill(.background)
                .ignoresSafeArea(edges: [.top, .horizontal])
        }
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
                totalRounds: totalRounds,
                showsCurrentPulse: isRunning && !isPaused && !isComplete
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
