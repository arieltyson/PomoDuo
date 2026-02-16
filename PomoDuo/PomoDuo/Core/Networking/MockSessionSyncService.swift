//
//  MockSessionSyncService.swift
//  PomoDuo
//
//  Created by Codex on 2/16/26.
//

import Foundation

/// In-memory ``SessionSyncService`` used for local development and tests.
///
/// Simulates real-time backend behavior by broadcasting every write to
/// active stream listeners for that session ID.
actor MockSessionSyncService: SessionSyncService {
    private let simulatedDelay: Duration

    private var sessionsByID: [String: StudySession] = [:]
    private var listenersBySessionID: [String: [UUID: AsyncStream<StudySession>.Continuation]] = [:]

    init(simulatedDelay: Duration = .zero) {
        self.simulatedDelay = simulatedDelay
    }

    func writeSession(_ session: StudySession) async throws {
        try await performDelayIfNeeded()

        sessionsByID[session.id] = session
        emit(session, sessionID: session.id)
    }

    func sessionStream(for sessionID: String) -> AsyncStream<StudySession> {
        AsyncStream { continuation in
            let listenerID = UUID()
            attach(continuation, listenerID: listenerID, sessionID: sessionID)

            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                Task {
                    await self.detach(listenerID: listenerID, sessionID: sessionID)
                }
            }
        }
    }

    func createSession(_ session: StudySession) async throws -> String {
        try await performDelayIfNeeded()

        sessionsByID[session.id] = session
        emit(session, sessionID: session.id)
        return session.id
    }

    func deleteSession(_ sessionID: String) async throws {
        try await performDelayIfNeeded()

        sessionsByID.removeValue(forKey: sessionID)

        guard let listeners = listenersBySessionID.removeValue(forKey: sessionID) else {
            return
        }

        for continuation in listeners.values {
            continuation.finish()
        }
    }

    // MARK: - Test Helpers

    func session(for sessionID: String) -> StudySession? {
        sessionsByID[sessionID]
    }

    var sessionCount: Int {
        sessionsByID.count
    }

    func reset() {
        sessionsByID.removeAll()

        for listeners in listenersBySessionID.values {
            for continuation in listeners.values {
                continuation.finish()
            }
        }
        listenersBySessionID.removeAll()
    }

    // MARK: - Private

    private func attach(
        _ continuation: AsyncStream<StudySession>.Continuation,
        listenerID: UUID,
        sessionID: String
    ) {
        if let existing = sessionsByID[sessionID] {
            continuation.yield(existing)
        }

        var listeners = listenersBySessionID[sessionID] ?? [:]
        listeners[listenerID] = continuation
        listenersBySessionID[sessionID] = listeners
    }

    private func detach(listenerID: UUID, sessionID: String) {
        listenersBySessionID[sessionID]?.removeValue(forKey: listenerID)
        if listenersBySessionID[sessionID]?.isEmpty == true {
            listenersBySessionID.removeValue(forKey: sessionID)
        }
    }

    private func emit(_ session: StudySession, sessionID: String) {
        guard let listeners = listenersBySessionID[sessionID] else {
            return
        }

        for continuation in listeners.values {
            continuation.yield(session)
        }
    }

    private func performDelayIfNeeded() async throws {
        guard simulatedDelay > .zero else { return }
        try await Task.sleep(for: simulatedDelay)
    }
}
