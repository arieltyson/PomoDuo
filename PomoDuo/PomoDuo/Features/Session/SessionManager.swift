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

    /// The current user's display name for notifications.
    var currentDisplayName: String?

    // MARK: - Dependencies

    private let syncService: (any SessionSyncService)?
    private let restrictionService: (any RestrictionService)?
    private let notificationService: (any NotificationService)?
    private let focusScheduler: FocusActivityScheduler?

    // MARK: - Initialization

    init(
        syncService: (any SessionSyncService)? = nil,
        restrictionService: (any RestrictionService)? = nil,
        notificationService: (any NotificationService)? = nil,
        focusScheduler: FocusActivityScheduler? = nil
    ) {
        self.syncService = syncService
        self.restrictionService = restrictionService
        self.notificationService = notificationService
        self.focusScheduler = focusScheduler
    }

    // MARK: - Intent Methods

    /// Initiates a new session request to the partner.
    func requestSession(
        partnerID: String,
        duration: TimeInterval = 25 * 60,
        shortBreakDuration: TimeInterval = 5 * 60,
        longBreakDuration: TimeInterval = 15 * 60,
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
            shortBreakDuration: shortBreakDuration,
            longBreakDuration: longBreakDuration,
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
                from: currentDisplayName ?? "Your partner"
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
        let initiatorID = session.partnerA
        let acceptorName = currentDisplayName ?? "Your partner"
        applyEvent(.accepted, to: session)
        await syncAndEnforce()

        try? await notificationService?.sendSessionAcceptedNotification(
            to: initiatorID,
            acceptedBy: acceptorName
        )
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
            let name = currentDisplayName ?? "Your partner"
            try? await notificationService?.sendPauseNotification(
                to: partnerID,
                pausedBy: name
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
        let partnerID = currentUserID.flatMap { session.partnerID(for: $0) }
        let userName = currentDisplayName ?? "Your partner"
        applyEvent(.completed, to: session)
        await syncAndEnforce()

        if let partnerID {
            try? await notificationService?.sendSessionEndedNotification(
                to: partnerID,
                endedBy: userName
            )
        }
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
        focusScheduler?.stopMonitoring()
        ShieldSessionContext.clearSession()

        currentSession = nil
        lastError = nil
    }

    // MARK: - Remote Sync Handling

    /// Call this when a remote session update arrives from the sync layer.
    ///
    /// In addition to updating local state, this enforces local-only side
    /// effects (restrictions + notifications) without writing back to the
    /// backend, which avoids remote write loops between paired devices.
    func handleRemoteUpdate(_ remoteSession: StudySession) async {
        let previousState = currentSession?.state
        let wasPaused = currentSession?.isPaused ?? false

        currentSession = remoteSession
        lastError = nil

        await enforceLocalSideEffects(
            for: remoteSession,
            previousState: previousState,
            wasPaused: wasPaused
        )
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

        // Enforce local restrictions/notifications for this transition.
        await enforceRestrictions(for: session)
    }

    /// Applies local side effects for a remote update.
    ///
    /// This avoids duplicate calls when Firestore emits the same session state
    /// repeatedly while still reacting to meaningful changes.
    private func enforceLocalSideEffects(
        for session: StudySession,
        previousState: SessionState?,
        wasPaused: Bool
    ) async {
        let stateChanged = previousState != session.state
        let pauseToggled = wasPaused != session.isPaused

        guard stateChanged || pauseToggled else {
            return
        }

        await enforceRestrictions(for: session)
    }

    /// Shared side-effect enforcement used by both local transitions and
    /// remote updates.
    ///
    /// In addition to managing restrictions and notifications, this writes
    /// session context to the App Group for the Shield Configuration extension
    /// and schedules/cancels DeviceActivity monitoring for the Monitor extension.
    private func enforceRestrictions(for session: StudySession) async {
        switch session.state {
        case .focus where !session.isPaused && !session.hasReachedPhaseEnd():
            try? await restrictionService?.applyRestrictions()
            if session.targetEndDate > .now {
                try? await notificationService?.scheduleTimerEndNotification(
                    at: session.targetEndDate,
                    message: "Focus session complete! Time for a break."
                )
            }
            // Write context so the Shield extension shows the right message
            // and the Monitor extension can reapply shields if the app is killed.
            ShieldSessionContext.writeSession(
                partnerName: nil,
                phase: "Focus",
                targetEndDate: session.targetEndDate
            )
            focusScheduler?.scheduleMonitoring(until: session.targetEndDate)

        case .focus:
            try? await restrictionService?.removeRestrictions()
            try? await notificationService?.cancelPendingNotifications()
            focusScheduler?.stopMonitoring()
            ShieldSessionContext.clearSession()

        case .shortBreak where session.targetEndDate > .now:
            try? await restrictionService?.removeRestrictions()
            try? await notificationService?.scheduleTimerEndNotification(
                at: session.targetEndDate,
                message: "Break's over! Ready to focus?"
            )
            // Shields are removed during breaks; clear the monitor schedule.
            focusScheduler?.stopMonitoring()
            ShieldSessionContext.clearSession()

        case .longBreak where session.targetEndDate > .now:
            try? await restrictionService?.removeRestrictions()
            try? await notificationService?.scheduleTimerEndNotification(
                at: session.targetEndDate,
                message: "Break's over! Ready to focus?"
            )
            // Shields are removed during breaks; clear the monitor schedule.
            focusScheduler?.stopMonitoring()
            ShieldSessionContext.clearSession()

        case .shortBreak, .longBreak:
            try? await restrictionService?.removeRestrictions()
            try? await notificationService?.cancelPendingNotifications()
            focusScheduler?.stopMonitoring()
            ShieldSessionContext.clearSession()

        case .completed, .idle:
            try? await restrictionService?.removeRestrictions()
            try? await notificationService?.cancelPendingNotifications()
            focusScheduler?.stopMonitoring()
            ShieldSessionContext.clearSession()

        default:
            break
        }
    }
}
