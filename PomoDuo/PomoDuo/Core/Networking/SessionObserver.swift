import Foundation
import OSLog
import Observation

/// Coordinates real-time session sync between paired devices.
///
/// `SessionObserver` runs two layered listeners:
///
/// 1. **Discovery listener** — watches for any session where the current user
///    is a member (via ``SessionSyncService/activeSessionStream(for:)``).
///    This is how Partner B discovers an incoming request from Partner A.
///
/// 2. **Session listener** — once an active session is found, subscribes to
///    that specific session document (via ``SessionSyncService/sessionStream(for:)``)
///    for granular real-time updates (pause, resume, break, complete).
///
/// All updates flow into ``SessionManager/handleRemoteUpdate(_:)`` so the UI
/// reacts immediately to the partner's actions.
///
/// - Note: Ownership is enforced via two monotonic epochs in addition to
///   `Task.cancel()`. Cancellation is cooperative — a task that has already
///   resumed past its `!Task.isCancelled` check can still push a late
///   remote update into the session manager before it observes cancellation.
///   Each task captures its owning epoch at creation, and the final
///   "apply" step rejects writes whose epoch is no longer current. Discovery
///   and per-session listeners track separate epochs so replacing the
///   session listener mid-discovery doesn't invalidate discovery itself.
@MainActor
@Observable
final class SessionObserver {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.arieljtyson.PomoDuo",
        category: "SessionObserver"
    )

    private let syncService: any SessionSyncService
    private let sessionManager: SessionManager

    /// Task that discovers active sessions for the current user.
    private var discoveryTask: Task<Void, Never>?

    /// Task that listens to a specific session's real-time updates.
    private var sessionListenerTask: Task<Void, Never>?

    /// The session ID currently being observed for granular updates.
    private var observedSessionID: String?

    /// Ownership token for the discovery listener. Bumped on every
    /// `startObserving` / `stopObserving`.
    private var discoveryEpoch: UInt64 = 0

    /// Ownership token for the per-session listener. Bumped on every
    /// `startSessionListener` / `stopSessionListener`.
    private var sessionListenerEpoch: UInt64 = 0

    #if DEBUG
    /// Pending test continuations awaiting the next successful observer
    /// processing. Resumed once when an emission is applied under the
    /// current epoch, or on stop to release any waiters without deadlock.
    private var debugProcessingContinuations:
        [CheckedContinuation<Void, Never>] = []
    #endif

    init(syncService: any SessionSyncService, sessionManager: SessionManager) {
        self.syncService = syncService
        self.sessionManager = sessionManager
    }

    /// Begins listening for active sessions involving the given user.
    ///
    /// Call this after authentication completes. If the user signs out and
    /// signs back in, call ``stopObserving()`` first, then call this again
    /// with the new user ID.
    func startObserving(userID: String) {
        stopObserving()

        discoveryEpoch &+= 1
        let epoch = discoveryEpoch

        Self.logger.info("Starting session observation for user.")

        discoveryTask = Task { @MainActor [weak self, syncService] in
            for await session in await syncService.activeSessionStream(for: userID) {
                guard let self, self.discoveryEpoch == epoch else { return }

                if let session {
                    Self.logger.debug(
                        "Discovered active session \(session.id, privacy: .public) in state \(session.state.rawValue, privacy: .public)."
                    )

                    self.startSessionListener(for: session.id)
                    await self.sessionManager.handleRemoteUpdate(session)

                    guard self.discoveryEpoch == epoch else { return }
                    self.signalProcessedEmissionForTests()
                } else {
                    Self.logger.debug("No active session found.")

                    // Only clear the local session listener if the user didn't
                    // just create one locally (before Firestore reflects it).
                    let currentState = self.sessionManager.currentSession?.state
                    if currentState == nil
                        || currentState == .idle
                        || currentState == .completed
                    {
                        self.stopSessionListener()
                    }

                    guard self.discoveryEpoch == epoch else { return }
                    self.signalProcessedEmissionForTests()
                }
            }
        }
    }

    /// Stops all session listeners.
    ///
    /// Call this when the user signs out or the observer is no longer needed.
    func stopObserving() {
        discoveryTask?.cancel()
        discoveryTask = nil
        discoveryEpoch &+= 1
        stopSessionListener()
        releasePendingTestSignals()
    }

    /// Subscribes to the specific session document for granular real-time updates.
    ///
    /// If the observer is already listening to this session, the call is a no-op.
    /// If a different session was being observed, its listener is replaced.
    func startSessionListener(for sessionID: String) {
        guard sessionID != observedSessionID else { return }

        stopSessionListener()
        observedSessionID = sessionID

        sessionListenerEpoch &+= 1
        let epoch = sessionListenerEpoch

        Self.logger.info(
            "Attaching session listener for \(sessionID, privacy: .public)."
        )

        sessionListenerTask = Task { @MainActor [weak self, syncService] in
            for await session in await syncService.sessionStream(for: sessionID) {
                guard let self, self.sessionListenerEpoch == epoch else {
                    return
                }
                await self.sessionManager.handleRemoteUpdate(session)

                guard self.sessionListenerEpoch == epoch else { return }
                self.signalProcessedEmissionForTests()
            }

            guard let self, self.sessionListenerEpoch == epoch else { return }
            Self.logger.debug(
                "Session stream ended for \(sessionID, privacy: .public)."
            )
            self.observedSessionID = nil
        }
    }

    /// Stops the session-specific listener without stopping discovery.
    private func stopSessionListener() {
        sessionListenerTask?.cancel()
        sessionListenerTask = nil
        observedSessionID = nil
        sessionListenerEpoch &+= 1
    }

    // MARK: - Test Signal

    #if DEBUG
    /// Awaits the next successful observer emission processing.
    ///
    /// Resumes once when a discovery or session-listener emission has been
    /// applied to ``SessionManager`` under the current epoch, or when the
    /// observer is stopped (so callers never deadlock). This replaces
    /// probabilistic `Task.sleep` / polling in tests with a deterministic
    /// tick-level signal driven by actual observer progress.
    func waitForNextObserverProcessingForTests() async {
        await withCheckedContinuation { continuation in
            debugProcessingContinuations.append(continuation)
        }
    }
    #endif

    private func signalProcessedEmissionForTests() {
        #if DEBUG
        let waiters = debugProcessingContinuations
        debugProcessingContinuations.removeAll()
        for continuation in waiters {
            continuation.resume()
        }
        #endif
    }

    private func releasePendingTestSignals() {
        #if DEBUG
        let waiters = debugProcessingContinuations
        debugProcessingContinuations.removeAll()
        for continuation in waiters {
            continuation.resume()
        }
        #endif
    }
}
