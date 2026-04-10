import SwiftData
import SwiftUI

/// Active paired-session surface shown in the Partner tab.
///
/// Integrates with persistence, Live Activity, haptics, accessibility,
/// Screen Time restrictions, network connectivity status, heartbeat
/// monitoring, and partner presence indicators.
struct ActivePairedSessionView: View {
    let session: StudySession
    let partner: PartnerProfile
    let viewModel: PartnerSessionViewModel

    @Environment(\.modelContext) private var modelContext
    @Environment(AuthManager.self) private var authManager
    @Environment(LiveActivityManager.self) private var liveActivityManager
    @Environment(RestrictionCoordinator.self) private var restrictionCoordinator
    @Environment(HeartbeatManager.self) private var heartbeatManager
    @Environment(FocusStatsReporter.self) private var focusStatsReporter
    @Environment(ConnectionMonitor.self) private var connectionMonitor
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var haptic = HapticTrigger()
    @State private var focusStartedAt: Date?
    @State private var hasAnnouncedRequestState = false
    @State private var hasReachedPhaseEnd = false
    @State private var isShowingEndConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            PartnerBannerView(
                partner: partner,
                isPartnerActive: heartbeatManager.isPartnerActive
            )

            Spacer()

            SessionPhaseBadge(
                session: session,
                hasReachedPhaseEnd: currentPhaseHasEnded
            )

            PairedCountdownView(
                session: session,
                hasReachedPhaseEnd: currentPhaseHasEnded
            )

            PairedRoundProgress(
                currentRound: session.currentRound,
                totalRounds: session.totalRounds
            )

            Spacer()

            VStack {
                PairedSessionControls(
                    session: session,
                    viewModel: viewModel,
                    hasReachedPhaseEnd: currentPhaseHasEnded,
                    isShowingEndConfirmation: $isShowingEndConfirmation
                )

                if restrictionCoordinator.isRestricting {
                    PairedBlockingIndicatorView()
                }
            }
            .padding(.bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .top, spacing: 6) {
            ConnectionStatusBanner()
        }
        .animation(.smooth, value: connectionMonitor.isConnected)
        .confirmationDialog(
            "End study session?",
            isPresented: $isShowingEndConfirmation,
            titleVisibility: .visible
        ) {
            Button("End Session", role: .destructive) {
                Task { await viewModel.endSession() }
            }
        } message: {
            Text("This will end the session for both you and your partner.")
        }
        .sensoryFeedback(haptic.feedback, trigger: haptic)
        .animation(
            reduceMotion ? .none : .spring(duration: 0.35, bounce: 0.2),
            value: session.state
        )
        .animation(
            reduceMotion ? .none : .spring(duration: 0.35, bounce: 0.2),
            value: restrictionCoordinator.isRestricting
        )
        .animation(
            reduceMotion ? .none : .spring(duration: 0.35, bounce: 0.2),
            value: heartbeatManager.isPartnerActive
        )
        .alert(
            "Session Error",
            isPresented: sessionErrorIsPresented
        ) {
            Button("OK") {
                viewModel.dismissError()
            }
        } message: {
            if let sessionError = viewModel.sessionError {
                Text(sessionError)
            }
        }
        .onAppear {
            updateIdleTimer(isDisabled: sessionKeepsScreenAwake)
        }
        .onChange(of: sessionKeepsScreenAwake) { _, shouldKeepScreenAwake in
            updateIdleTimer(isDisabled: shouldKeepScreenAwake)
        }
        .onChange(of: session.state) { oldState, newState in
            handleStateTransition(from: oldState, to: newState)
        }
        .onChange(of: session.isPaused) { wasPaused, isPaused in
            handlePauseChange(wasPaused: wasPaused, isPaused: isPaused)
        }
        .task {
            ShieldSessionContext.writePartnerName(partner.displayName)
            configureForInitialState()
        }
        .task(
            id: PhaseDeadlineTaskID(
                state: session.state,
                isPaused: session.isPaused,
                targetEndDate: session.targetEndDate
            )
        ) {
            await observePhaseDeadline()
        }
        .onDisappear {
            updateIdleTimer(isDisabled: false)
        }
    }

    private var currentPhaseHasEnded: Bool {
        hasReachedPhaseEnd || session.hasReachedPhaseEnd()
    }

    private var sessionErrorIsPresented: Binding<Bool> {
        Binding(
            get: { viewModel.sessionError != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.dismissError()
                }
            }
        )
    }

    private var sessionKeepsScreenAwake: Bool {
        switch session.state {
        case .focus, .shortBreak, .longBreak:
            !currentPhaseHasEnded
        case .idle, .requesting, .completed:
            false
        }
    }

    private func observePhaseDeadline() async {
        hasReachedPhaseEnd = session.hasReachedPhaseEnd()

        guard session.supportsCountdown else {
            return
        }

        guard !session.isPaused, !hasReachedPhaseEnd else {
            return
        }

        let remaining = session.targetEndDate.timeIntervalSinceNow
        guard remaining > 0 else {
            return
        }

        do {
            try await Task.sleep(for: .seconds(remaining))
        } catch {
            return
        }

        guard !Task.isCancelled else {
            return
        }

        hasReachedPhaseEnd = true
        liveActivityManager.end()

        if session.state == .focus {
            restrictionCoordinator.liftRestrictions()
        }
    }

    private struct PhaseDeadlineTaskID: Equatable {
        let state: SessionState
        let isPaused: Bool
        let targetEndDate: Date
    }

    private func updateIdleTimer(isDisabled: Bool) {
        UIApplication.shared.isIdleTimerDisabled = isDisabled
    }

    // MARK: - State Transitions

    private func configureForInitialState() {
        hasReachedPhaseEnd = session.hasReachedPhaseEnd()

        switch session.state {
        case .requesting:
            if !hasAnnouncedRequestState {
                AccessibilityAnnouncer.announcePairedSessionStarted(
                    partnerName: partner.displayName
                )
                hasAnnouncedRequestState = true
            }
        case .focus:
            focusStartedAt = session.startTime
            guard !currentPhaseHasEnded else {
                liveActivityManager.end()
                restrictionCoordinator.liftRestrictions()
                return
            }

            startLiveActivityForFocus(isPaused: session.isPaused)
            if !session.isPaused {
                restrictionCoordinator.enforceFocusRestrictions()
            }
        case .shortBreak:
            guard !currentPhaseHasEnded else {
                liveActivityManager.end()
                restrictionCoordinator.liftRestrictions()
                return
            }

            updateLiveActivityForBreak(isLong: false)
            restrictionCoordinator.liftRestrictions()
        case .longBreak:
            guard !currentPhaseHasEnded else {
                liveActivityManager.end()
                restrictionCoordinator.liftRestrictions()
                return
            }

            updateLiveActivityForBreak(isLong: true)
            restrictionCoordinator.liftRestrictions()
        case .idle, .completed:
            liveActivityManager.end()
            restrictionCoordinator.liftRestrictions()
        }
    }

    private func handleStateTransition(
        from oldState: SessionState,
        to newState: SessionState
    ) {
        hasReachedPhaseEnd = session.hasReachedPhaseEnd()

        switch (oldState, newState) {

        case (.requesting, .focus):
            focusStartedAt = session.startTime
            haptic.fire(.start)
            startLiveActivityForFocus(isPaused: session.isPaused)
            restrictionCoordinator.enforceFocusRestrictions()
            AccessibilityAnnouncer.announcePairedFocusBegan(
                round: session.currentRound,
                totalRounds: session.totalRounds,
                partnerName: partner.displayName
            )

        case (.focus, .shortBreak):
            recordCompletedFocusRound()
            haptic.fire(.phaseChange)
            updateLiveActivityForBreak(isLong: false)
            restrictionCoordinator.liftRestrictions()
            AccessibilityAnnouncer.announcePairedBreak(isLong: false)

        case (.focus, .longBreak):
            recordCompletedFocusRound()
            haptic.fire(.phaseChange)
            updateLiveActivityForBreak(isLong: true)
            restrictionCoordinator.liftRestrictions()
            AccessibilityAnnouncer.announcePairedBreak(isLong: true)

        case (.shortBreak, .focus), (.longBreak, .focus):
            focusStartedAt = session.startTime
            haptic.fire(.start)
            startLiveActivityForFocus(isPaused: session.isPaused)
            restrictionCoordinator.enforceFocusRestrictions()
            AccessibilityAnnouncer.announcePairedFocusBegan(
                round: session.currentRound,
                totalRounds: session.totalRounds,
                partnerName: partner.displayName
            )

        case (.focus, .completed):
            recordPartialFocusRound()
            haptic.fire(.complete)
            liveActivityManager.end()
            restrictionCoordinator.liftRestrictions()
            AccessibilityAnnouncer.announcePairedSessionCompleted()

        case (.longBreak, .completed):
            haptic.fire(.complete)
            liveActivityManager.end()
            AccessibilityAnnouncer.announcePairedSessionCompleted()

        case (.focus, .idle):
            recordPartialFocusRound()
            haptic.fire(.stop)
            liveActivityManager.end()
            restrictionCoordinator.forceRemoveRestrictions()
            AccessibilityAnnouncer.announcePairedSessionEnded()

        case (.requesting, .idle),
            (.shortBreak, .idle),
            (.longBreak, .idle),
            (.completed, .idle):
            haptic.fire(.stop)
            liveActivityManager.end()
            restrictionCoordinator.forceRemoveRestrictions()
            AccessibilityAnnouncer.announcePairedSessionEnded()

        default:
            break
        }
    }

    private func handlePauseChange(wasPaused: Bool, isPaused: Bool) {
        guard session.state == .focus else { return }

        if !wasPaused && isPaused {
            haptic.fire(.pause)
            updateLiveActivityPaused(true)
            restrictionCoordinator.liftRestrictions()
            AccessibilityAnnouncer.announcePairedPause()
        } else if wasPaused && !isPaused {
            haptic.fire(.resume)
            updateLiveActivityPaused(false)
            restrictionCoordinator.enforceFocusRestrictions()
            AccessibilityAnnouncer.announcePairedResume()
        }
    }

    // MARK: - Persistence

    private func recordCompletedFocusRound() {
        let startedAt = focusStartedAt ?? session.startTime
        let elapsed = Date.now.timeIntervalSince(startedAt)
        let focusDuration = min(elapsed, session.duration)

        guard focusDuration >= 60 else { return }

        let completedSession = CompletedSession(
            startedAt: startedAt,
            focusDuration: focusDuration,
            roundNumber: session.currentRound,
            totalRounds: session.totalRounds,
            sessionType: .paired,
            userID: authManager.currentUserID
        )

        modelContext.insert(completedSession)
        focusStatsReporter.report(focusMinutes: completedSession.focusMinutes)
        focusStartedAt = nil
        refreshWidgetData()
    }

    /// Records a partial focus round when the session is ended early.
    ///
    /// Only records if at least 60 seconds of focus elapsed, preventing
    /// accidental taps from inflating totals.
    private func recordPartialFocusRound() {
        guard let startedAt = focusStartedAt else { return }

        let elapsed = Date.now.timeIntervalSince(startedAt)
        guard elapsed >= 60 else { return }

        let completedSession = CompletedSession(
            startedAt: startedAt,
            focusDuration: elapsed,
            roundNumber: session.currentRound,
            totalRounds: session.totalRounds,
            sessionType: .paired,
            userID: authManager.currentUserID
        )

        modelContext.insert(completedSession)
        focusStatsReporter.report(focusMinutes: completedSession.focusMinutes)
        focusStartedAt = nil
        refreshWidgetData()
    }

    // MARK: - Widget Refresh

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

        let todayMinutes = todaySessions.reduce(0) { partial, session in
            partial + session.focusMinutes
        }
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
        guard let userID = authManager.currentUserID else {
            return sessions
        }

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
                let previousDay = calendar.date(
                    byAdding: .day,
                    value: -1,
                    to: cursor
                )
            else {
                break
            }
            cursor = previousDay
        }

        return streak
    }

    // MARK: - Live Activity

    private func startLiveActivityForFocus(isPaused: Bool) {
        liveActivityManager.start(
            phase: .focus,
            currentRound: session.currentRound,
            totalRounds: session.totalRounds,
            targetEndDate: session.targetEndDate,
            phaseDuration: session.duration
        )

        if isPaused {
            let remaining = max(
                0,
                session.targetEndDate.timeIntervalSinceNow
            )
            liveActivityManager.update(
                phase: .focus,
                currentRound: session.currentRound,
                targetEndDate: session.targetEndDate,
                isPaused: true,
                phaseDuration: session.duration,
                pausedRemainingSeconds: remaining
            )
        }
    }

    private func updateLiveActivityForBreak(isLong: Bool) {
        liveActivityManager.update(
            phase: isLong ? .longBreak : .shortBreak,
            currentRound: session.currentRound,
            targetEndDate: session.targetEndDate,
            isPaused: false,
            phaseDuration: session.currentPhaseDuration
        )
    }

    private func updateLiveActivityPaused(_ isPaused: Bool) {
        let remaining =
            isPaused
            ? max(0, session.targetEndDate.timeIntervalSinceNow)
            : 0
        liveActivityManager.update(
            phase: .focus,
            currentRound: session.currentRound,
            targetEndDate: session.targetEndDate,
            isPaused: isPaused,
            phaseDuration: session.duration,
            pausedRemainingSeconds: remaining
        )
    }
}
