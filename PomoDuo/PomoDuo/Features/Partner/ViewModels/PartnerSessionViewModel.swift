import Foundation
import Observation

/// Coordinates paired-session actions between Partner UI and ``SessionManager``.
@MainActor
@Observable
final class PartnerSessionViewModel {
    let sessionManager: SessionManager

    /// Whether session creation is currently in progress.
    private(set) var isStartingSession = false

    /// User-facing error copied from the latest state-machine transition failure.
    private(set) var sessionError: String?

    /// Set to `true` when a paired session action is blocked because
    /// a solo focus session is already running on the Timer tab.
    var isShowingSoloSessionConflict = false

    private let soloSessionStore: SoloTimerSessionStore

    init(
        sessionManager: SessionManager,
        soloSessionStore: SoloTimerSessionStore = SoloTimerSessionStore()
    ) {
        self.sessionManager = sessionManager
        self.soloSessionStore = soloSessionStore
    }

    /// Whether a solo timer session is currently active.
    private var hasSoloSessionActive: Bool {
        soloSessionStore.load() != nil
    }

    // MARK: - Computed State

    var activeSession: StudySession? {
        sessionManager.currentSession
    }

    var hasActiveSession: Bool {
        guard let activeSession else { return false }
        return activeSession.state != .idle && activeSession.state != .completed
    }

    /// `true` when the current user is the *receiver* of a session request
    /// (Partner B) rather than the initiator (Partner A).
    ///
    /// The UI uses this to show Accept/Decline buttons instead of
    /// the "Waiting for Partner" spinner.
    var isIncomingRequest: Bool {
        guard let session = activeSession,
            session.state == .requesting,
            let userID = sessionManager.currentUserID
        else { return false }
        return session.partnerB == userID
    }

    var isWaitingForAcceptance: Bool {
        guard let session = activeSession,
            session.state == .requesting,
            let userID = sessionManager.currentUserID
        else { return false }
        return session.partnerA == userID
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

    // MARK: - Initiator Actions (Partner A)

    func startSession(
        with partner: PartnerProfile,
        duration: TimeInterval = 25 * 60,
        shortBreakDuration: TimeInterval = 5 * 60,
        longBreakDuration: TimeInterval = 15 * 60,
        totalRounds: Int = 4
    ) async {
        guard !isStartingSession else { return }
        guard activeSession == nil else { return }
        guard !hasSoloSessionActive else {
            isShowingSoloSessionConflict = true
            return
        }
        guard sessionManager.currentUserID != nil else {
            sessionError = "Sign in before starting a paired session."
            return
        }

        isStartingSession = true
        sessionError = nil

        await sessionManager.requestSession(
            partnerID: partner.id,
            duration: duration,
            shortBreakDuration: shortBreakDuration,
            longBreakDuration: longBreakDuration,
            totalRounds: totalRounds
        )
        syncErrorFromManager()

        isStartingSession = false
    }

    // MARK: - Receiver Actions (Partner B)

    /// Partner B accepts an incoming session request.
    ///
    /// This transitions the session from `.requesting` to `.focus` and
    /// syncs the change to Firestore so Partner A's device picks it up
    /// via ``SessionObserver``.
    func acceptIncomingSession() async {
        guard isIncomingRequest else { return }
        guard !hasSoloSessionActive else {
            isShowingSoloSessionConflict = true
            return
        }
        await sessionManager.acceptSession()
        syncErrorFromManager()
    }

    /// Partner B declines an incoming session request.
    ///
    /// This transitions the session to `.idle` and clears it from both
    /// the local state and Firestore.
    func declineIncomingSession() async {
        guard isIncomingRequest else { return }
        await sessionManager.declineSession()
        await sessionManager.clearSession()
        syncErrorFromManager()
    }

    // MARK: - Shared Session Actions

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
        sessionError = nil
        isStartingSession = false
    }

    // MARK: - Private

    private func syncErrorFromManager() {
        sessionError = sessionManager.lastError?.description
    }
}
