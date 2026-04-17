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

    /// Whether a paired session is currently in an active (non-terminal) state.
    ///
    /// Returns `true` for `.requesting`, `.focus`, `.shortBreak`, and
    /// `.longBreak` — any state where a partner session is in flight and
    /// a solo focus session must not be started. Returns `false` for
    /// `.idle`, `.completed`, and `nil` (no session).
    var hasActivePairedSession: Bool {
        guard let state = currentSession?.state else { return false }
        switch state {
        case .requesting, .focus, .shortBreak, .longBreak:
            return true
        case .idle, .completed:
            return false
        }
    }

    /// The current user's ID (set after authentication).
    var currentUserID: String?

    /// The current user's display name for notifications.
    var currentDisplayName: String?

    // MARK: - Dependencies

    private let syncService: (any SessionSyncService)?
    private let notificationService: (any NotificationService)?

    /// Single owner of every Screen Time side effect for paired sessions.
    ///
    /// Held weakly because the app shell owns both the manager and the
    /// coordinator and we don't want a retain cycle through the coordinator's
    /// own back-reference into ``ScreenTimeManager``. `nil` is safe — paired
    /// state transitions still update local + remote state, just without
    /// driving Screen Time enforcement (the configuration tests rely on this).
    ///
    /// Before this consolidation, `SessionManager` directly held a
    /// `RestrictionService`, a `FocusActivityScheduler`, and wrote
    /// `ShieldSessionContext` itself. That meant remote-driven paired updates
    /// (the ones that arrive through ``handleRemoteUpdate(_:)`` even when
    /// no Partner view is mounted) wrote shields, scheduled monitoring, and
    /// updated App-Group context without ever touching the coordinator —
    /// leaving `coordinator.isRestricting` stale, `runtimeHealth` un-refreshed,
    /// and the active-session chip pointed at the wrong source of truth.
    private weak var restrictionCoordinator: RestrictionCoordinator?

    // MARK: - Initialization

    init(
        syncService: (any SessionSyncService)? = nil,
        notificationService: (any NotificationService)? = nil,
        restrictionCoordinator: RestrictionCoordinator? = nil
    ) {
        self.syncService = syncService
        self.notificationService = notificationService
        self.restrictionCoordinator = restrictionCoordinator
    }

    /// Late-binds the Screen Time owner.
    ///
    /// ``PomoDuoApp`` constructs the coordinator and the manager in the same
    /// `init`, so the wired path uses the initializer. This setter exists so
    /// test scaffolding can build a manager first and attach a coordinator
    /// once the supporting mocks are in place.
    func attachRestrictionCoordinator(_ coordinator: RestrictionCoordinator) {
        self.restrictionCoordinator = coordinator
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
    ///
    /// Screen Time teardown is delegated to ``RestrictionCoordinator``
    /// (`forceRemoveRestrictions()`) so the coordinator's `isRestricting`
    /// flag, `ShieldSessionContext`, and DeviceActivity schedule come down
    /// together. Bypassing the coordinator here would leave its in-memory
    /// flag stuck at `true` while shields were already removed.
    func clearSession() async {
        if let sessionID = currentSession?.id {
            try? await syncService?.deleteSession(sessionID)
        }

        restrictionCoordinator?.forceRemoveRestrictions()
        try? await notificationService?.cancelPendingNotifications()

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
    /// **Ownership boundary.** Screen Time side effects (shield writes,
    /// `ShieldSessionContext`, DeviceActivity monitoring schedule, and the
    /// runtime-health refresh) are delegated to ``RestrictionCoordinator``.
    /// Notification side effects stay here because they're a paired-session
    /// concern, not a Screen Time pipeline concern.
    ///
    /// Routing every state-driven Screen Time write through the coordinator
    /// is what closes the remote-update bypass: `handleRemoteUpdate(_:)` runs
    /// even when no Partner view is mounted, so the coordinator is the only
    /// piece guaranteed to be reachable on every transition.
    private func enforceRestrictions(for session: StudySession) async {
        switch session.state {
        case .focus where !session.isPaused && !session.hasReachedPhaseEnd():
            restrictionCoordinator?.enforceFocusRestrictions(
                until: session.targetEndDate
            )
            if session.targetEndDate > .now {
                try? await notificationService?.scheduleTimerEndNotification(
                    at: session.targetEndDate,
                    message: "Focus session complete! Time for a break."
                )
            }

        case .focus:
            restrictionCoordinator?.liftRestrictions()
            try? await notificationService?.cancelPendingNotifications()

        case .shortBreak where session.targetEndDate > .now,
            .longBreak where session.targetEndDate > .now:
            restrictionCoordinator?.liftRestrictions()
            try? await notificationService?.scheduleTimerEndNotification(
                at: session.targetEndDate,
                message: "Break's over! Ready to focus?"
            )

        case .shortBreak, .longBreak, .completed, .idle:
            restrictionCoordinator?.liftRestrictions()
            try? await notificationService?.cancelPendingNotifications()

        default:
            break
        }
    }
}
