import Foundation
import Observation

/// Coordinates paired-session actions between Partner UI and ``SessionManager``.
@MainActor
@Observable
final class PartnerSessionViewModel {
    private let sessionManager: SessionManager
    private let autoAcceptDelay: Duration
    private var autoAcceptTask: Task<Void, Never>?

    /// Whether session creation is currently in progress.
    private(set) var isStartingSession = false

    /// User-facing error copied from the latest state-machine transition failure.
    private(set) var sessionError: String?

    init(
        sessionManager: SessionManager,
        autoAcceptDelay: Duration = .seconds(1.5)
    ) {
        self.sessionManager = sessionManager
        self.autoAcceptDelay = autoAcceptDelay
    }

    var activeSession: StudySession? {
        sessionManager.currentSession
    }

    var hasActiveSession: Bool {
        guard let activeSession else { return false }
        return activeSession.state != .idle && activeSession.state != .completed
    }

    var isWaitingForAcceptance: Bool {
        activeSession?.state == .requesting
    }

    var isFocusing: Bool {
        activeSession?.state == .focus && activeSession?.isPaused == false
    }

    var isPaused: Bool {
        activeSession?.isPaused == true
    }

    var isOnBreak: Bool {
        guard let state = activeSession?.state else { return false }
        return state == .shortBreak || state == .longBreak
    }

    var isCompleted: Bool {
        activeSession?.state == .completed
    }

    var lastTransitionError: SessionStateMachine.TransitionError? {
        sessionManager.lastError
    }

    func startSession(
        with partner: PartnerProfile,
        duration: TimeInterval = 25 * 60,
        totalRounds: Int = 4
    ) async {
        guard !isStartingSession else { return }
        guard activeSession == nil else { return }
        guard sessionManager.currentUserID != nil else {
            sessionError = "Sign in before starting a paired session."
            return
        }

        isStartingSession = true
        sessionError = nil

        await sessionManager.requestSession(
            partnerID: partner.id,
            duration: duration,
            totalRounds: totalRounds
        )
        syncErrorFromManager()

        if isWaitingForAcceptance {
            simulatePartnerAcceptanceForLocalDevelopment()
        }

        isStartingSession = false
    }

    func pauseSession() async {
        await sessionManager.pause()
        syncErrorFromManager()
    }

    func resumeSession() async {
        await sessionManager.resume()
        syncErrorFromManager()
    }

    func beginBreak() async {
        await sessionManager.beginBreak()
        syncErrorFromManager()
    }

    func beginFocus() async {
        await sessionManager.beginFocus()
        syncErrorFromManager()
    }

    /// Ends an active session according to the current lifecycle state.
    func endSession() async {
        guard let activeSession else { return }

        switch activeSession.state {
        case .requesting:
            await sessionManager.declineSession()
            await sessionManager.clearSession()
        case .focus, .longBreak:
            await sessionManager.completeSession()
        case .shortBreak, .completed, .idle:
            await sessionManager.clearSession()
        }

        syncErrorFromManager()
    }

    func dismissError() {
        sessionError = nil
    }

    func reset() {
        autoAcceptTask?.cancel()
        autoAcceptTask = nil
        sessionError = nil
        isStartingSession = false
    }

    private func syncErrorFromManager() {
        sessionError = sessionManager.lastError?.description
    }

    private func simulatePartnerAcceptanceForLocalDevelopment() {
        autoAcceptTask?.cancel()

        autoAcceptTask = Task { [weak self] in
            guard let self else { return }

            try? await Task.sleep(for: autoAcceptDelay)

            guard !Task.isCancelled,
                self.isWaitingForAcceptance
            else {
                return
            }

            await self.sessionManager.acceptSession()
            self.syncErrorFromManager()
            self.autoAcceptTask = nil
        }
    }
}
