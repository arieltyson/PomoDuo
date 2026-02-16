//
//  MockSessionSyncServiceTests.swift
//  PomoDuoTests
//
//  Created by Codex on 2/16/26.
//

import Foundation
import Testing
@testable import PomoDuo

@Suite("MockSessionSyncService")
@MainActor
struct MockSessionSyncServiceTests {
    private func makeSession(
        id: String = UUID().uuidString,
        state: SessionState = .idle
    ) -> StudySession {
        StudySession(
            id: id,
            partnerA: "user-a",
            partnerB: "user-b",
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

    @Test("create stores session and returns session ID")
    func createStoresSession() async throws {
        let service = MockSessionSyncService()
        let session = makeSession(id: "session-create")

        let returnedID = try await service.createSession(session)

        #expect(returnedID == "session-create")
        let storedSession = await service.session(for: "session-create")
        #expect(storedSession == session)
    }

    @Test("write updates existing session")
    func writeUpdatesSession() async throws {
        let service = MockSessionSyncService()
        var session = makeSession(id: "session-write", state: .idle)
        _ = try await service.createSession(session)

        session.state = .focus
        try await service.writeSession(session)

        let storedSession = await service.session(for: "session-write")
        #expect(storedSession?.state == .focus)
    }

    @Test("delete removes session")
    func deleteRemovesSession() async throws {
        let service = MockSessionSyncService()
        let session = makeSession(id: "session-delete")
        _ = try await service.createSession(session)

        try await service.deleteSession("session-delete")

        let storedSession = await service.session(for: "session-delete")
        #expect(storedSession == nil)
        let count = await service.sessionCount
        #expect(count == 0)
    }

    @Test("stream emits current session snapshot immediately")
    func streamEmitsSnapshot() async throws {
        let service = MockSessionSyncService()
        let session = makeSession(id: "session-stream-snapshot")
        _ = try await service.createSession(session)

        let stream = await service.sessionStream(for: "session-stream-snapshot")
        var iterator = stream.makeAsyncIterator()
        let firstValue = await iterator.next()

        #expect(firstValue == session)
    }

    @Test("stream emits updates after write")
    func streamEmitsWriteUpdates() async throws {
        let service = MockSessionSyncService()
        var session = makeSession(id: "session-stream-update", state: .idle)
        _ = try await service.createSession(session)

        let stream = await service.sessionStream(for: "session-stream-update")
        var iterator = stream.makeAsyncIterator()

        _ = await iterator.next()

        session.state = .focus
        try await service.writeSession(session)

        let updatedValue = await iterator.next()
        #expect(updatedValue?.state == .focus)
    }

    @Test("stream finishes when session is deleted")
    func streamFinishesOnDelete() async throws {
        let service = MockSessionSyncService()
        let session = makeSession(id: "session-stream-delete")
        _ = try await service.createSession(session)

        let stream = await service.sessionStream(for: "session-stream-delete")
        var iterator = stream.makeAsyncIterator()
        _ = await iterator.next()

        try await service.deleteSession("session-stream-delete")
        let terminalValue = await iterator.next()

        #expect(terminalValue == nil)
    }

    @Test("reset clears all stored sessions")
    func resetClearsAllSessions() async throws {
        let service = MockSessionSyncService()
        _ = try await service.createSession(makeSession(id: "s1"))
        _ = try await service.createSession(makeSession(id: "s2"))

        await service.reset()

        let count = await service.sessionCount
        #expect(count == 0)
    }

    @Test("operations honor simulated delay")
    func honorsSimulatedDelay() async throws {
        let service = MockSessionSyncService(simulatedDelay: .milliseconds(75))
        let session = makeSession(id: "session-delay")

        let start = ContinuousClock.now
        _ = try await service.createSession(session)
        let elapsed = ContinuousClock.now - start

        #expect(elapsed >= .milliseconds(50))
    }
}
