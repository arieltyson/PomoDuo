import Foundation

/// In-memory ``SessionSyncService`` used for local development and tests.
///
/// Simulates real-time backend behavior by broadcasting every write to
/// active stream listeners for that session ID.
actor MockSessionSyncService: SessionSyncService {
    private let simulatedDelay: Duration

    private var sessionsByID: [String: StudySession] = [:]
    private var listenersBySessionID:
        [String: [UUID: AsyncStream<StudySession>.Continuation]] = [:]
    private var activeSessionListeners:
        [UUID: ActiveSessionListener] = [:]

    private struct ActiveSessionListener {
        let userID: String
        let continuation: AsyncStream<StudySession?>.Continuation
    }

    init(simulatedDelay: Duration = .zero) {
        self.simulatedDelay = simulatedDelay
    }

    func writeSession(_ session: StudySession) async throws {
        try await performDelayIfNeeded()

        sessionsByID[session.id] = session
        emit(session, sessionID: session.id)
        emitActiveSessionUpdate(for: session)
    }

    func sessionStream(for sessionID: String) -> AsyncStream<StudySession> {
        AsyncStream { continuation in
            let listenerID = UUID()
            attach(continuation, listenerID: listenerID, sessionID: sessionID)

            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                Task {
                    await self.detach(
                        listenerID: listenerID,
                        sessionID: sessionID
                    )
                }
            }
        }
    }

    func createSession(_ session: StudySession) async throws -> String {
        try await performDelayIfNeeded()

        sessionsByID[session.id] = session
        emit(session, sessionID: session.id)
        emitActiveSessionUpdate(for: session)
        return session.id
    }

    func deleteSession(_ sessionID: String) async throws {
        try await performDelayIfNeeded()

        let removedSession = sessionsByID.removeValue(forKey: sessionID)

        if let listeners = listenersBySessionID.removeValue(forKey: sessionID) {
            for continuation in listeners.values {
                continuation.finish()
            }
        }

        if let removedSession {
            emitActiveSessionRemoval(for: removedSession)
        }
    }

    func activeSessionStream(for userID: String) -> AsyncStream<StudySession?> {
        AsyncStream { continuation in
            let listenerID = UUID()
            attachActiveSessionListener(
                continuation,
                listenerID: listenerID,
                userID: userID
            )

            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                Task {
                    await self.detachActiveSessionListener(id: listenerID)
                }
            }
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

        for listener in activeSessionListeners.values {
            listener.continuation.finish()
        }
        activeSessionListeners.removeAll()
    }

    // MARK: - Private — Session Stream

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

    // MARK: - Private — Active Session Stream

    private static let terminalStates: Set<SessionState> = [
        .completed,
        .idle,
    ]

    private func attachActiveSessionListener(
        _ continuation: AsyncStream<StudySession?>.Continuation,
        listenerID: UUID,
        userID: String
    ) {
        activeSessionListeners[listenerID] = ActiveSessionListener(
            userID: userID,
            continuation: continuation
        )

        continuation.yield(activeSession(for: userID))
    }

    private func detachActiveSessionListener(id: UUID) {
        activeSessionListeners.removeValue(forKey: id)
    }

    private func emitActiveSessionUpdate(for session: StudySession) {
        for listener in activeSessionListeners.values
        where containsUser(listener.userID, in: session)
        {
            listener.continuation.yield(activeSession(for: listener.userID))
        }
    }

    private func emitActiveSessionRemoval(for session: StudySession) {
        for listener in activeSessionListeners.values
        where containsUser(listener.userID, in: session)
        {
            listener.continuation.yield(activeSession(for: listener.userID))
        }
    }

    private func activeSession(for userID: String) -> StudySession? {
        sessionsByID.values
            .filter { session in
                containsUser(userID, in: session) && !Self.terminalStates.contains(session.state)
            }
            .max(by: { $0.startTime < $1.startTime })
    }

    private func containsUser(_ userID: String, in session: StudySession) -> Bool {
        session.partnerA == userID || session.partnerB == userID
    }

    private func performDelayIfNeeded() async throws {
        guard simulatedDelay > .zero else { return }
        try await Task.sleep(for: simulatedDelay)
    }
}
