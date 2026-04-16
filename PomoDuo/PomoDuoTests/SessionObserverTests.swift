import Foundation
import Testing

@testable import PomoDuo

@Suite("SessionObserver")
@MainActor
struct SessionObserverTests {
    private func makeSession(
        id: String = "session-1",
        partnerA: String = "user-a",
        partnerB: String = "user-b",
        state: SessionState = .requesting
    ) -> StudySession {
        StudySession(
            id: id,
            partnerA: partnerA,
            partnerB: partnerB,
            state: state,
            startTime: .now,
            targetEndDate: .now.addingTimeInterval(25 * 60),
            duration: 25 * 60,
            isPaused: false,
            pausedBy: nil,
            currentRound: 1,
            totalRounds: 4
        )
    }

    private func makeDependencies() -> (
        syncService: MockSessionSyncService,
        sessionManager: SessionManager,
        observer: SessionObserver
    ) {
        let syncService = MockSessionSyncService()
        let sessionManager = SessionManager(syncService: syncService)
        sessionManager.setCurrentUserID("user-b")

        let observer = SessionObserver(
            syncService: syncService,
            sessionManager: sessionManager
        )

        return (syncService, sessionManager, observer)
    }

    /// Awaits until the given predicate holds over `sessionManager.currentSession`.
    ///
    /// Each iteration blocks on the observer's deterministic post-emission
    /// signal, so the test advances only when the observer has actually
    /// processed another tick — never on a wall-clock sleep. The `maxTicks`
    /// ceiling surfaces a broken wiring as a test failure instead of an
    /// indefinite hang; with the epoch-guarded observer, a correctly-behaving
    /// run converges in 1–2 ticks.
    private func awaitState(
        _ observer: SessionObserver,
        _ sessionManager: SessionManager,
        maxTicks: Int = 20,
        _ predicate: (StudySession?) -> Bool
    ) async {
        if predicate(sessionManager.currentSession) { return }
        for _ in 0..<maxTicks {
            await observer.waitForNextObserverProcessingForTests()
            if predicate(sessionManager.currentSession) { return }
        }
    }

    /// Drains pending main-actor work so post-cancel absence assertions
    /// measure the steady state, not a mid-cancellation snapshot.
    private func drainMainActor(rounds: Int = 10) async {
        for _ in 0..<rounds {
            await Task.yield()
        }
    }

    @Test("discovers an existing active session on start")
    func discoversActiveSession() async throws {
        let (syncService, sessionManager, observer) = makeDependencies()
        let session = makeSession()
        _ = try await syncService.createSession(session)

        observer.startObserving(userID: "user-b")
        await awaitState(observer, sessionManager) { $0?.id == session.id }

        #expect(sessionManager.currentSession?.id == session.id)
        observer.stopObserving()
    }

    @Test("ignores sessions where current user is not a member")
    func ignoresUnrelatedSession() async throws {
        let (syncService, sessionManager, observer) = makeDependencies()
        let unrelatedSession = makeSession(
            partnerA: "user-x",
            partnerB: "user-y",
            state: .focus
        )
        _ = try await syncService.createSession(unrelatedSession)

        observer.startObserving(userID: "user-b")
        // Wait for the discovery tick confirming the empty initial emission.
        await observer.waitForNextObserverProcessingForTests()

        #expect(sessionManager.currentSession == nil)
        observer.stopObserving()
    }

    @Test("session listener receives subsequent state updates")
    func sessionListenerReceivesUpdates() async throws {
        let (syncService, sessionManager, observer) = makeDependencies()
        var session = makeSession(state: .requesting)
        _ = try await syncService.createSession(session)

        observer.startObserving(userID: "user-b")
        await awaitState(observer, sessionManager) {
            $0?.state == .requesting
        }
        #expect(sessionManager.currentSession?.state == .requesting)

        session.state = .focus
        session.startTime = .now
        session.targetEndDate = .now.addingTimeInterval(25 * 60)
        try await syncService.writeSession(session)

        await awaitState(observer, sessionManager) { $0?.state == .focus }
        #expect(sessionManager.currentSession?.state == .focus)
        observer.stopObserving()
    }

    @Test("pause updates propagate through the observer")
    func pauseUpdatePropagates() async throws {
        let (syncService, sessionManager, observer) = makeDependencies()
        var session = makeSession(state: .focus)
        _ = try await syncService.createSession(session)

        observer.startObserving(userID: "user-b")
        await awaitState(observer, sessionManager) { $0?.state == .focus }
        #expect(sessionManager.currentSession?.state == .focus)

        session.isPaused = true
        session.pausedBy = "user-a"
        try await syncService.writeSession(session)

        await awaitState(observer, sessionManager) { $0?.isPaused == true }
        #expect(sessionManager.currentSession?.isPaused == true)
        #expect(sessionManager.currentSession?.pausedBy == "user-a")
        observer.stopObserving()
    }

    @Test("stopObserving cancels discovery and session listeners")
    func stopObservingCancelsAllListeners() async throws {
        let (syncService, sessionManager, observer) = makeDependencies()
        var session = makeSession(state: .focus)
        _ = try await syncService.createSession(session)

        observer.startObserving(userID: "user-b")
        await awaitState(observer, sessionManager) { $0?.state == .focus }

        observer.stopObserving()

        // Post-stop writes must NOT reach sessionManager. Even if a lingering
        // task resumes past its `!Task.isCancelled` guard, the epoch check
        // makes the apply step a no-op.
        session.state = .shortBreak
        try await syncService.writeSession(session)
        await drainMainActor()

        #expect(sessionManager.currentSession?.state == .focus)
    }

    @Test(
        "restarting observation for a new identity clears old session context"
    )
    func restartObservationForNewIdentity() async throws {
        let (syncService, sessionManager, observer) = makeDependencies()
        let sessionForB = makeSession(
            id: "session-b",
            partnerA: "user-a",
            partnerB: "user-b",
            state: .focus
        )
        _ = try await syncService.createSession(sessionForB)

        observer.startObserving(userID: "user-b")
        await awaitState(observer, sessionManager) { $0?.id == "session-b" }

        sessionManager.setCurrentUserID("user-c")
        observer.startObserving(userID: "user-c")
        await awaitState(observer, sessionManager) { $0 == nil }

        #expect(sessionManager.currentSession == nil)
        observer.stopObserving()
    }

    /// Regression: a stream emission received by a task that has already
    /// passed its `!Task.isCancelled` guard must not be applied to
    /// ``SessionManager`` if the observer has been stopped before the task
    /// reaches the apply step.
    @Test("Epoch guard rejects late writes after stop")
    func epochGuardRejectsLateWrites() async throws {
        let (syncService, sessionManager, observer) = makeDependencies()
        let session = makeSession(state: .focus)
        _ = try await syncService.createSession(session)

        observer.startObserving(userID: "user-b")
        await awaitState(observer, sessionManager) { $0?.state == .focus }

        observer.stopObserving()
        #expect(sessionManager.currentSession?.state == .focus)

        var later = session
        later.state = .shortBreak
        try await syncService.writeSession(later)
        await drainMainActor()

        #expect(sessionManager.currentSession?.state == .focus)
    }
}
