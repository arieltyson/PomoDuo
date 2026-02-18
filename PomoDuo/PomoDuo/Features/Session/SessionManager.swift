import Foundation
import Observation

/// The single source of truth for session state.
/// The UI binds to this; it delegates all transitions to `SessionStateMachine`.
@MainActor
@Observable
final class SessionManager {

    // MARK: - Published State

    /// The current active session, or `nil` if no session is in progress.
    private(set) var currentSession: StudySession?

    /// The most recent error from a failed transition, surfaced to the UI.
    private(set) var lastError: SessionStateMachine.TransitionError?

    /// The current user's ID (set after authentication).
    var currentUserID: String?

    // MARK: - Dependencies

    private let syncService: (any SessionSyncService)?
    private let restrictionService: (any RestrictionService)?
    private let notificationService: (any NotificationService)?

    // MARK: - Initialization

    init(
        syncService: (any SessionSyncService)? = nil,
        restrictionService: (any RestrictionService)? = nil,
        notificationService: (any NotificationService)? = nil
    ) {
        self.syncService = syncService
        self.restrictionService = restrictionService
        self.notificationService = notificationService
    }

    // MARK: - Intent Methods

    /// Initiates a new session request to the partner.
    func requestSession(
        partnerID: String,
        duration: TimeInterval = 25 * 60,
        totalRounds: Int = 4
    ) async {
        guard let userID = currentUserID else { return }

        let session = StudySession(
            id: UUID().uuidString,
            partnerA: userID,
            partnerB: partnerID,
            state: .idle,
            startTime: .now,
            targetEndDate: .now.addingTimeInterval(duration),
            duration: duration,
            isPaused: false,
            pausedBy: nil,
            currentRound: 1,
            totalRounds: totalRounds
        )

        applyEvent(.requestSent, to: session)

        if let currentSession {
            _ = try? await syncService?.createSession(currentSession)
            try? await notificationService?.sendSessionRequest(
                to: partnerID,
                from: userID
            )
        }
    }

    /// Updates the identity context used for session operations.
    ///
    /// Clears local session state whenever the identity changes to avoid
    /// carrying partner session data across different authenticated users.
    func setCurrentUserID(_ userID: String?) {
        let previousUserID = currentUserID
        currentUserID = userID

        guard previousUserID != userID else {
            return
        }

        currentSession = nil
        lastError = nil
    }

    /// Partner B accepts the session request.
    func acceptSession() async {
        guard let session = currentSession else { return }
        applyEvent(.accepted, to: session)
        await syncAndEnforce()
    }

    /// Partner B declines the session request.
    func declineSession() async {
        guard let session = currentSession else { return }
        applyEvent(.declined, to: session)
        await syncAndEnforce()
    }

    /// Pauses the active focus session.
    func pause() async {
        guard let session = currentSession, let userID = currentUserID else {
            return
        }
        applyEvent(.paused(by: userID), to: session)
        await syncAndEnforce()

        if let partnerID = session.partnerID(for: userID) {
            try? await notificationService?.sendPauseNotification(
                to: partnerID,
                pausedBy: userID
            )
        }
    }

    /// Resumes a paused session.
    func resume() async {
        guard let session = currentSession else { return }
        applyEvent(.resumed, to: session)
        await syncAndEnforce()

        if let userID = currentUserID,
            let partnerID = session.partnerID(for: userID)
        {
            try? await notificationService?.sendResumeNotification(
                to: partnerID
            )
        }
    }

    /// Transitions from focus to break.
    func beginBreak() async {
        guard let session = currentSession else { return }
        applyEvent(.breakBegan, to: session)
        await syncAndEnforce()
    }

    /// Transitions from break to the next focus round.
    func beginFocus() async {
        guard let session = currentSession else { return }
        applyEvent(.focusBegan, to: session)
        await syncAndEnforce()
    }

    /// Marks the session as completed.
    func completeSession() async {
        guard let session = currentSession else { return }
        applyEvent(.completed, to: session)
        await syncAndEnforce()
    }

    /// Clears the current session and related side effects.
    ///
    /// Use this to dismiss completed or cancelled sessions and return
    /// the UI to the idle pairing state.
    func clearSession() async {
        if let sessionID = currentSession?.id {
            try? await syncService?.deleteSession(sessionID)
        }

        try? await restrictionService?.removeRestrictions()
        try? await notificationService?.cancelPendingNotifications()

        currentSession = nil
        lastError = nil
    }

    // MARK: - Remote Sync Handling

    /// Call this when a remote session update arrives from the sync layer.
    func handleRemoteUpdate(_ remoteSession: StudySession) {
        currentSession = remoteSession
        lastError = nil
    }

    // MARK: - Private

    /// Applies an event through the state machine and updates local state.
    private func applyEvent(_ event: SessionEvent, to session: StudySession) {
        do {
            currentSession = try SessionStateMachine.apply(event, to: session)
            lastError = nil
        } catch let error as SessionStateMachine.TransitionError {
            lastError = error
        } catch {
            // Unexpected error; should never happen with our typed transition errors.
        }
    }

    /// Syncs the current session to the backend and enforces or removes restrictions.
    private func syncAndEnforce() async {
        guard let session = currentSession else { return }

        // Sync to backend.
        try? await syncService?.writeSession(session)

        // Enforce or remove restrictions based on state.
        switch session.state {
        case .focus where !session.isPaused:
            try? await restrictionService?.applyRestrictions()
            try? await notificationService?.scheduleTimerEndNotification(
                at: session.targetEndDate,
                message: "Focus session complete! Time for a break."
            )
        case .shortBreak, .longBreak:
            try? await restrictionService?.removeRestrictions()
            try? await notificationService?.scheduleTimerEndNotification(
                at: session.targetEndDate,
                message: "Break's over! Ready to focus?"
            )
        case .completed, .idle:
            try? await restrictionService?.removeRestrictions()
            try? await notificationService?.cancelPendingNotifications()
        default:
            break
        }
    }
}
