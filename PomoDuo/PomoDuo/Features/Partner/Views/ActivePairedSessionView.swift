//
//  ActivePairedSessionView.swift
//  PomoDuo
//
//  Created by Codex on 2/16/26.
//

import SwiftData
import SwiftUI

/// Active paired-session surface shown in the Partner tab.
///
/// Integrates with persistence, Live Activity, haptics, and accessibility.
struct ActivePairedSessionView: View {
    let session: StudySession
    let partner: PartnerProfile
    let viewModel: PartnerSessionViewModel

    @Environment(\.modelContext) private var modelContext
    @Environment(AuthManager.self) private var authManager
    @Environment(LiveActivityManager.self) private var liveActivityManager

    @State private var haptic = HapticTrigger()
    @State private var focusStartedAt: Date?
    @State private var hasAnnouncedRequestState = false

    var body: some View {
        VStack {
            PartnerBannerView(partner: partner)

            Spacer()

            SessionPhaseBadge(session: session)

            PairedCountdownView(session: session)

            PairedRoundProgress(
                currentRound: session.currentRound,
                totalRounds: session.totalRounds
            )

            Spacer()

            PairedSessionControls(
                session: session,
                viewModel: viewModel
            )
            .padding(.bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sensoryFeedback(haptic.feedback, trigger: haptic)
        .animation(.default, value: session.state)
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
        .onChange(of: session.state) { oldState, newState in
            handleStateTransition(from: oldState, to: newState)
        }
        .onChange(of: session.isPaused) { wasPaused, isPaused in
            handlePauseChange(wasPaused: wasPaused, isPaused: isPaused)
        }
        .task {
            configureForInitialState()
        }
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

    // MARK: - State Transitions

    private func configureForInitialState() {
        switch session.state {
        case .requesting:
            if !hasAnnouncedRequestState {
                AccessibilityAnnouncer.announcePairedSessionStarted(partnerName: partner.displayName)
                hasAnnouncedRequestState = true
            }
        case .focus:
            focusStartedAt = session.startTime
            startLiveActivityForFocus(isPaused: session.isPaused)
        default:
            break
        }
    }

    private func handleStateTransition(from oldState: SessionState, to newState: SessionState) {
        switch (oldState, newState) {

        case (.requesting, .focus):
            focusStartedAt = session.startTime
            haptic.fire(.start)
            startLiveActivityForFocus(isPaused: session.isPaused)
            AccessibilityAnnouncer.announcePairedFocusBegan(
                round: session.currentRound,
                totalRounds: session.totalRounds,
                partnerName: partner.displayName
            )

        case (.focus, .shortBreak):
            recordCompletedFocusRound()
            haptic.fire(.phaseChange)
            updateLiveActivityForBreak(isLong: false)
            AccessibilityAnnouncer.announcePairedBreak(isLong: false)

        case (.focus, .longBreak):
            recordCompletedFocusRound()
            haptic.fire(.phaseChange)
            updateLiveActivityForBreak(isLong: true)
            AccessibilityAnnouncer.announcePairedBreak(isLong: true)

        case (.shortBreak, .focus), (.longBreak, .focus):
            focusStartedAt = session.startTime
            haptic.fire(.start)
            startLiveActivityForFocus(isPaused: session.isPaused)
            AccessibilityAnnouncer.announcePairedFocusBegan(
                round: session.currentRound,
                totalRounds: session.totalRounds,
                partnerName: partner.displayName
            )

        case (.focus, .completed):
            haptic.fire(.complete)
            liveActivityManager.end()
            AccessibilityAnnouncer.announcePairedSessionCompleted()

        case (.longBreak, .completed):
            haptic.fire(.complete)
            liveActivityManager.end()
            AccessibilityAnnouncer.announcePairedSessionCompleted()

        case (.requesting, .idle),
             (.focus, .idle),
             (.shortBreak, .idle),
             (.longBreak, .idle),
             (.completed, .idle):
            haptic.fire(.stop)
            liveActivityManager.end()
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
            AccessibilityAnnouncer.announcePairedPause()
        } else if wasPaused && !isPaused {
            haptic.fire(.resume)
            updateLiveActivityPaused(false)
            AccessibilityAnnouncer.announcePairedResume()
        }
    }

    // MARK: - Persistence

    private func recordCompletedFocusRound() {
        let startedAt = focusStartedAt ?? session.startTime

        let completedSession = CompletedSession(
            startedAt: startedAt,
            focusDuration: session.duration,
            roundNumber: session.currentRound,
            totalRounds: session.totalRounds,
            sessionType: .paired,
            userID: authManager.currentUserID
        )

        modelContext.insert(completedSession)
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
        let todaySessions = scopedSessions.filter { calendar.isDate($0.dayBucket, inSameDayAs: today) }

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

    private func sessionsForCurrentUser(from sessions: [CompletedSession]) -> [CompletedSession] {
        guard let userID = authManager.currentUserID else {
            return sessions
        }

        return sessions.filter { $0.userID == nil || $0.userID == userID }
    }

    private func streakCount(from dayBuckets: [Date], calendar: Calendar, today: Date) -> Int {
        let activeDays = Set(dayBuckets.map { calendar.startOfDay(for: $0) })
        var cursor = today
        var streak = 0

        while activeDays.contains(cursor) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: cursor) else {
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
            targetEndDate: session.targetEndDate
        )

        if isPaused {
            liveActivityManager.update(
                phase: .focus,
                currentRound: session.currentRound,
                targetEndDate: session.targetEndDate,
                isPaused: true
            )
        }
    }

    private func updateLiveActivityForBreak(isLong: Bool) {
        liveActivityManager.update(
            phase: isLong ? .longBreak : .shortBreak,
            currentRound: session.currentRound,
            targetEndDate: session.targetEndDate,
            isPaused: false
        )
    }

    private func updateLiveActivityPaused(_ isPaused: Bool) {
        liveActivityManager.update(
            phase: .focus,
            currentRound: session.currentRound,
            targetEndDate: session.targetEndDate,
            isPaused: isPaused
        )
    }
}

private struct PartnerBannerView: View {
    let partner: PartnerProfile

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

            Image(systemName: "person.2.fill")
                .foregroundStyle(AppColors.lavender)
                .accessibilityHidden(true)
        }
        .padding()
        .background(AppColors.paleViolet.opacity(0.14), in: .rect(cornerRadius: 14))
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Studying with \(partner.displayName)")
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

    var body: some View {
        Label(phaseLabel, systemImage: phaseSymbol)
            .font(.title3)
            .bold()
            .foregroundStyle(phaseColor)
            .padding(.vertical)
            .accessibilityAddTraits(.isHeader)
    }

    private var phaseLabel: String {
        switch session.state {
        case .requesting:
            "Waiting for Partner"
        case .focus where session.isPaused:
            "Paused"
        case .focus:
            "Focus"
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
        case .focus:
            "brain.head.profile"
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
        case .focus:
            AppColors.lavender
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

    var body: some View {
        Group {
            switch session.state {
            case .requesting:
                RequestingCountdownView()
            case .completed:
                CompletedCountdownView()
            default:
                if session.isPaused {
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
    var body: some View {
        VStack {
            Image(systemName: "party.popper.fill")
                .font(.largeTitle)
                .foregroundStyle(AppColors.lavender)

            Text("Great work!")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }
}

private struct PausedCountdownView: View {
    let targetEndDate: Date

    var body: some View {
        Text(remainingText)
            .font(.largeTitle)
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .accessibilityValue(remainingText)
    }

    private var remainingText: String {
        let remainingSeconds = max(0, Int(targetEndDate.timeIntervalSinceNow))
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60

        let minutesText = minutes < 10 ? "0\(minutes)" : "\(minutes)"
        let secondsText = seconds < 10 ? "0\(seconds)" : "\(seconds)"
        return "\(minutesText):\(secondsText)"
    }
}

private struct LiveCountdownView: View {
    let targetEndDate: Date

    var body: some View {
        Text(timerInterval: Date.now...targetEndDate, countsDown: true)
            .font(.largeTitle)
            .monospacedDigit()
            .bold()
            .contentTransition(.numericText())
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

    var body: some View {
        Circle()
            .fill(fillColor)
            .frame(width: 12, height: 12)
            .overlay {
                if isCurrent {
                    Circle()
                        .stroke(AppColors.lavender, lineWidth: 2)
                        .frame(width: 18, height: 18)
                }
            }
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

    @State private var isShowingEndConfirmation = false

    var body: some View {
        VStack {
            switch session.state {
            case .requesting:
                Button("Cancel", systemImage: "xmark.circle", role: .destructive) {
                    Task {
                        await viewModel.endSession()
                    }
                }
                .buttonStyle(.bordered)

            case .focus where session.isPaused:
                HStack {
                    Button("Resume", systemImage: "play.fill") {
                        Task {
                            await viewModel.resumeSession()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppColors.lavender)

                    Button("End Session", systemImage: "stop.fill", role: .destructive) {
                        isShowingEndConfirmation = true
                    }
                    .buttonStyle(.bordered)
                }

            case .focus:
                HStack {
                    Button("Pause", systemImage: "pause.fill") {
                        Task {
                            await viewModel.pauseSession()
                        }
                    }
                    .buttonStyle(.bordered)

                    Button("Skip to Break", systemImage: "forward.fill") {
                        Task {
                            await viewModel.beginBreak()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.teal)
                }

            case .shortBreak, .longBreak:
                HStack {
                    Button("Next Round", systemImage: "play.fill") {
                        Task {
                            await viewModel.beginFocus()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppColors.lavender)

                    Button("End Session", systemImage: "stop.fill", role: .destructive) {
                        isShowingEndConfirmation = true
                    }
                    .buttonStyle(.bordered)
                }

            case .completed:
                Button("Done", systemImage: "checkmark") {
                    Task {
                        await viewModel.endSession()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.lavender)

            case .idle:
                EmptyView()
            }
        }
        .controlSize(.large)
        .confirmationDialog(
            "End study session?",
            isPresented: $isShowingEndConfirmation,
            titleVisibility: .visible
        ) {
            Button("End Session", role: .destructive) {
                Task {
                    await viewModel.endSession()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will end the session for both you and your partner.")
        }
    }
}
