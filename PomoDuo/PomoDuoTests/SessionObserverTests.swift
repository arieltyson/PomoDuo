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

    private func waitUntil(
        timeout: Duration = .seconds(1),
        pollingInterval: Duration = .milliseconds(10),
        _ condition: () -> Bool
    ) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now + timeout

        while clock.now < deadline {
            if condition() {
                return true
            }

            try? await Task.sleep(for: pollingInterval)
        }

        return condition()
    }

    @Test("discovers an existing active session on start")
    func discoversActiveSession() async throws {
        let (syncService, sessionManager, observer) = makeDependencies()
        let session = makeSession()
        _ = try await syncService.createSession(session)

        observer.startObserving(userID: "user-b")

        #expect(
            await waitUntil { sessionManager.currentSession?.id == session.id }
        )
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
        try await Task.sleep(for: .milliseconds(50))

        #expect(sessionManager.currentSession == nil)
        observer.stopObserving()
    }

    @Test("session listener receives subsequent state updates")
    func sessionListenerReceivesUpdates() async throws {
        let (syncService, sessionManager, observer) = makeDependencies()
        var session = makeSession(state: .requesting)
        _ = try await syncService.createSession(session)

        observer.startObserving(userID: "user-b")
        #expect(
            await waitUntil {
                sessionManager.currentSession?.state == .requesting
            }
        )

        session.state = .focus
        session.startTime = .now
        session.targetEndDate = .now.addingTimeInterval(25 * 60)
        try await syncService.writeSession(session)

        #expect(
            await waitUntil { sessionManager.currentSession?.state == .focus }
        )
        observer.stopObserving()
    }

    @Test("pause updates propagate through the observer")
    func pauseUpdatePropagates() async throws {
        let (syncService, sessionManager, observer) = makeDependencies()
        var session = makeSession(state: .focus)
        _ = try await syncService.createSession(session)

        observer.startObserving(userID: "user-b")
        #expect(
            await waitUntil { sessionManager.currentSession?.state == .focus }
        )

        session.isPaused = true
        session.pausedBy = "user-a"
        try await syncService.writeSession(session)

        #expect(
            await waitUntil { sessionManager.currentSession?.isPaused == true }
        )
        #expect(sessionManager.currentSession?.pausedBy == "user-a")
        observer.stopObserving()
    }

    @Test("stopObserving cancels discovery and session listeners")
    func stopObservingCancelsAllListeners() async throws {
        let (syncService, sessionManager, observer) = makeDependencies()
        var session = makeSession(state: .focus)
        _ = try await syncService.createSession(session)

        observer.startObserving(userID: "user-b")
        #expect(
            await waitUntil { sessionManager.currentSession?.state == .focus }
        )

        observer.stopObserving()

        session.state = .shortBreak
        try await syncService.writeSession(session)
        try await Task.sleep(for: .milliseconds(50))

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
        #expect(
            await waitUntil { sessionManager.currentSession?.id == "session-b" }
        )

        sessionManager.setCurrentUserID("user-c")
        observer.startObserving(userID: "user-c")
        try await Task.sleep(for: .milliseconds(50))

        #expect(sessionManager.currentSession == nil)
        observer.stopObserving()
    }
}
