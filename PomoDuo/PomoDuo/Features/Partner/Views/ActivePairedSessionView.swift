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
        .safeAreaInset(edge: .top, spacing: 0) {
            ConnectionStatusBanner()
        }
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

// MARK: - Partner Banner with Live Status

private struct PartnerBannerView: View {
    let partner: PartnerProfile
    let isPartnerActive: Bool

    var body: some View {
        HStack {
            PartnerInitialAvatar(name: partner.displayName)

            VStack(alignment: .leading) {
                Text("Studying with")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(partner.displayName)
                    .font(.headline)
            }

            Spacer()

            PartnerPresenceIndicator(isActive: isPartnerActive)
        }
        .padding()
        .background(
            AppColors.paleViolet.opacity(0.14),
            in: .rect(cornerRadius: 14)
        )
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Studying with \(partner.displayName), \(isPartnerActive ? "active" : "may be offline")"
        )
    }
}

/// Real-time partner presence dot with pulse animation.
///
/// Green pulsing dot when the partner's heartbeat is recent;
/// static orange dot when the partner may be offline.
/// When the Differentiate Without Color setting is on, the offline
/// dot gains a "!" mark so its state is conveyed by shape, not color.
private struct PartnerPresenceIndicator: View {
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityDifferentiateWithoutColor)
    private var differentiateWithoutColor
    @Environment(PowerStateMonitor.self) private var powerStateMonitor

    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(isActive ? .green : .orange)
                    .frame(width: 10, height: 10)

                if !isActive && differentiateWithoutColor {
                    Text("!")
                        .font(.system(size: 7, weight: .black))
                        .foregroundStyle(.white)
                }
            }
            .overlay {
                if isActive
                    && !reduceMotion
                    && !powerStateMonitor.isLowPowerModeEnabled
                {
                    PulsingRing()
                }
            }

            Text(isActive ? "Active" : "Offline?")
                .font(.caption2)
                .foregroundStyle(isActive ? .green : .orange)
        }
        .animation(.easeInOut(duration: 0.4), value: isActive)
    }
}

/// Subtle repeating pulse ring that radiates outward from the
/// presence dot while the partner is active.
private struct PulsingRing: View {
    @State private var isPulsing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(PowerStateMonitor.self) private var powerStateMonitor

    var body: some View {
        Circle()
            .stroke(Color.green.opacity(0.4), lineWidth: 2)
            .frame(width: 18, height: 18)
            .scaleEffect(isPulsing ? 1.3 : 1.0)
            .opacity(isPulsing ? 0.0 : 0.6)
            .task(
                id: AnimationTaskID(
                    reduceMotion: reduceMotion,
                    isLowPowerModeEnabled: powerStateMonitor.isLowPowerModeEnabled
                )
            ) {
                guard !reduceMotion, !powerStateMonitor.isLowPowerModeEnabled else {
                    isPulsing = false
                    return
                }
                withAnimation(
                    .easeInOut(duration: 1.5)
                        .repeatForever(autoreverses: false)
                ) {
                    isPulsing = true
                }
            }
    }

    private struct AnimationTaskID: Equatable {
        let reduceMotion: Bool
        let isLowPowerModeEnabled: Bool
    }
}

// MARK: - Subviews

private struct PairedBlockingIndicatorView: View {
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

private struct PartnerInitialAvatar: View {
    let name: String

    var body: some View {
        Text(initial)
            .font(.title3)
            .bold()
            .foregroundStyle(.white)
            .frame(width: 40, height: 40)
            .background(
                LinearGradient(
                    colors: [AppColors.lavender, AppColors.lilac],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: .circle
            )
            .accessibilityHidden(true)
    }

    private var initial: String {
        name.first.map(String.init) ?? "?"
    }
}

private struct SessionPhaseBadge: View {
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

private struct PairedCountdownView: View {
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

private struct PairedRoundProgress: View {
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

private struct PairedSessionControls: View {
    let session: StudySession
    let viewModel: PartnerSessionViewModel
    let hasReachedPhaseEnd: Bool
    @Binding var isShowingEndConfirmation: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 12) {
            Group {
                switch session.state {
                case .requesting:
                    Button(
                        "Cancel",
                        systemImage: "xmark.circle",
                        role: .destructive
                    ) {
                        Task {
                            await viewModel.endSession()
                        }
                    }
                    .buttonStyle(
                        PairedControlButtonStyle(tint: AppColors.stopTint)
                    )

                case .focus where session.isPaused:
                    HStack(spacing: 12) {
                        Button("End Session", systemImage: "stop.fill") {
                            isShowingEndConfirmation = true
                        }
                        .buttonStyle(
                            PairedControlButtonStyle(tint: AppColors.stopTint)
                        )
                        .accessibilityHint("Ends the session for both partners.")
                        .accessibilityInputLabels(["End Session", "End", "Stop"])

                        Button("Resume", systemImage: "play.fill") {
                            Task {
                                await viewModel.resumeSession()
                            }
                        }
                        .buttonStyle(
                            PairedControlButtonStyle(tint: AppColors.lavender)
                        )
                        .accessibilityHint("Continues the paused timer.")
                        .accessibilityInputLabels(["Resume", "Play", "Continue"])
                    }
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .scale(scale: 0.92).combined(with: .opacity)
                    )

                case .focus:
                    VStack(spacing: 10) {
                        if hasReachedPhaseEnd {
                            Button(
                                "Continue to Break",
                                systemImage: "arrow.right"
                            ) {
                                Task {
                                    await viewModel.beginBreak()
                                }
                            }
                            .buttonStyle(
                                PairedControlButtonStyle(tint: AppColors.success)
                            )
                            .accessibilityInputLabels([
                                "Continue to Break",
                                "Continue",
                                "Break",
                            ])
                        } else {
                            HStack(spacing: 12) {
                                Button("Pause", systemImage: "pause.fill") {
                                    Task {
                                        await viewModel.pauseSession()
                                    }
                                }
                                .buttonStyle(
                                    PairedControlButtonStyle(tint: AppColors.pauseTint)
                                )
                                .accessibilityHint("Pauses the timer for both partners.")

                                Button("Skip to Break", systemImage: "forward.fill") {
                                    Task {
                                        await viewModel.beginBreak()
                                    }
                                }
                                .buttonStyle(
                                    PairedControlButtonStyle(tint: AppColors.lavender)
                                )
                                .accessibilityInputLabels([
                                    "Skip to Break",
                                    "Skip",
                                    "Break",
                                ])
                            }
                        }

                        Button("End Session", systemImage: "stop.fill") {
                            isShowingEndConfirmation = true
                        }
                        .buttonStyle(
                            PairedControlButtonStyle(tint: AppColors.stopTint)
                        )
                        .accessibilityHint("Ends the session for both partners.")
                        .accessibilityInputLabels(["End Session", "End", "Stop"])
                    }
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .scale(scale: 0.92).combined(with: .opacity)
                    )

                case .shortBreak, .longBreak:
                    VStack(spacing: 10) {
                        Button(
                            hasReachedPhaseEnd
                                ? "Continue to Focus"
                                : "Next Round",
                            systemImage: hasReachedPhaseEnd
                                ? "arrow.right"
                                : "play.fill"
                        ) {
                            Task {
                                await viewModel.beginFocus()
                            }
                        }
                        .buttonStyle(
                            PairedControlButtonStyle(tint: AppColors.lavender)
                        )
                        .accessibilityInputLabels([
                            hasReachedPhaseEnd ? "Continue to Focus" : "Next Round",
                            "Next",
                            "Continue",
                        ])

                        Button("End Session", systemImage: "stop.fill") {
                            isShowingEndConfirmation = true
                        }
                        .buttonStyle(
                            PairedControlButtonStyle(tint: AppColors.stopTint)
                        )
                        .accessibilityHint("Ends the session for both partners.")
                        .accessibilityInputLabels(["End Session", "End", "Stop"])
                    }

                case .completed:
                    Button("Done", systemImage: "checkmark") {
                        Task {
                            await viewModel.endSession()
                        }
                    }
                    .buttonStyle(
                        PairedControlButtonStyle(tint: AppColors.success)
                    )
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .scale(scale: 0.85).combined(with: .opacity)
                    )

                case .idle:
                    EmptyView()
                }
            }
            .animation(
                reduceMotion ? .none : .spring(duration: 0.35, bounce: 0.2),
                value: session.state
            )
            .animation(
                reduceMotion ? .none : .spring(duration: 0.35, bounce: 0.2),
                value: session.isPaused
            )
        }
    }
}

/// Glass-material button style matching the solo session's ``SecondaryControlButtonStyle``.
private struct PairedControlButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(tint)
            .padding(.horizontal)
            .padding(.vertical)
            .background(.thinMaterial, in: .capsule)
            .overlay {
                Capsule()
                    .stroke(tint.opacity(0.36), lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

