import Foundation
@preconcurrency import FirebaseFirestore

/// Firestore-backed real-time sync implementation for paired sessions.
actor FirebaseSessionSyncService: SessionSyncService {
    private struct SessionEmissionKey: Equatable {
        let id: String
        let partnerA: String
        let partnerB: String
        let state: SessionState
        let startTime: Date
        let targetEndDate: Date
        let duration: TimeInterval
        let shortBreakDuration: TimeInterval
        let longBreakDuration: TimeInterval
        let isPaused: Bool
        let pausedBy: String?
        let currentRound: Int
        let totalRounds: Int

        init(session: StudySession) {
            id = session.id
            partnerA = session.partnerA
            partnerB = session.partnerB
            state = session.state
            startTime = session.startTime
            targetEndDate = session.targetEndDate
            duration = session.duration
            shortBreakDuration = session.shortBreakDuration
            longBreakDuration = session.longBreakDuration
            isPaused = session.isPaused
            pausedBy = session.pausedBy
            currentRound = session.currentRound
            totalRounds = session.totalRounds
        }
    }

    private enum Collections {
        static let sessions = "sessions"
    }

    private enum Fields {
        static let id = "id"
        static let partnerA = "partnerA"
        static let partnerB = "partnerB"
        static let members = "members"
        static let state = "state"
        static let startTime = "startTime"
        static let targetEndDate = "targetEndDate"
        static let duration = "duration"
        static let shortBreakDuration = "shortBreakDuration"
        static let longBreakDuration = "longBreakDuration"
        static let isPaused = "isPaused"
        static let pausedBy = "pausedBy"
        static let currentRound = "currentRound"
        static let totalRounds = "totalRounds"
        static let updatedAt = "updatedAt"
    }

    /// Session states that indicate a session is no longer active.
    private static let terminalStates: Set<String> = [
        SessionState.completed.rawValue,
        SessionState.idle.rawValue,
    ]

    private let database: Firestore

    init(database: Firestore = Firestore.firestore()) {
        self.database = database
    }

    func writeSession(_ session: StudySession) async throws {
        try await sessionReference(for: session.id).setData(
            encodeSession(session),
            merge: true
        )
    }

    func sessionStream(for sessionID: String) -> AsyncStream<StudySession> {
        let reference = sessionReference(for: sessionID)

        return AsyncStream { continuation in
            var lastYieldedKey: SessionEmissionKey?
            let listener = reference.addSnapshotListener { snapshot, error in
                if error != nil {
                    continuation.finish()
                    return
                }

                guard let snapshot else {
                    continuation.finish()
                    return
                }

                guard snapshot.exists else {
                    continuation.finish()
                    return
                }

                guard let session = Self.decodeSession(from: snapshot) else {
                    return
                }

                let sessionKey = SessionEmissionKey(session: session)
                guard sessionKey != lastYieldedKey else {
                    return
                }

                lastYieldedKey = sessionKey
                continuation.yield(session)
            }

            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }

    func createSession(_ session: StudySession) async throws -> String {
        try await sessionReference(for: session.id).setData(
            encodeSession(session),
            merge: false
        )
        return session.id
    }

    func deleteSession(_ sessionID: String) async throws {
        try await sessionReference(for: sessionID).delete()
    }

    func activeSessionStream(for userID: String) -> AsyncStream<StudySession?> {
        let query = database.collection(Collections.sessions)
            .whereField(Fields.members, arrayContains: userID)

        return AsyncStream { continuation in
            var lastYieldedKey: SessionEmissionKey?
            var hasYieldedSession = false
            let listener = query.addSnapshotListener { snapshot, error in
                let activeSession: StudySession?
                if error != nil {
                    activeSession = nil
                } else {
                    activeSession = snapshot?.documents
                        .compactMap(Self.decodeSession(from:))
                        .filter { !Self.terminalStates.contains($0.state.rawValue) }
                        .max(by: { $0.startTime < $1.startTime })
                }

                let sessionKey = activeSession.map(SessionEmissionKey.init(session:))
                if hasYieldedSession && sessionKey == lastYieldedKey {
                    return
                }

                lastYieldedKey = sessionKey
                hasYieldedSession = true
                continuation.yield(activeSession)
            }

            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }

    private func sessionReference(for sessionID: String) -> DocumentReference {
        database.collection(Collections.sessions).document(sessionID)
    }

    private func encodeSession(_ session: StudySession) -> [String: Any] {
        var data: [String: Any] = [
            Fields.id: session.id,
            Fields.partnerA: session.partnerA,
            Fields.partnerB: session.partnerB,
            Fields.members: [session.partnerA, session.partnerB],
            Fields.state: session.state.rawValue,
            Fields.startTime: session.startTime,
            Fields.targetEndDate: session.targetEndDate,
            Fields.duration: session.duration,
            Fields.shortBreakDuration: session.shortBreakDuration,
            Fields.longBreakDuration: session.longBreakDuration,
            Fields.isPaused: session.isPaused,
            Fields.currentRound: session.currentRound,
            Fields.totalRounds: session.totalRounds,
            Fields.updatedAt: FieldValue.serverTimestamp(),
        ]

        if let pausedBy = session.pausedBy {
            data[Fields.pausedBy] = pausedBy
        } else {
            data[Fields.pausedBy] = NSNull()
        }

        return data
    }

    private static func decodeSession(from snapshot: DocumentSnapshot) -> StudySession? {
        guard
            let data = snapshot.data(),
            let id = data[Fields.id] as? String,
            let partnerA = data[Fields.partnerA] as? String,
            let partnerB = data[Fields.partnerB] as? String,
            let rawState = data[Fields.state] as? String,
            let state = SessionState(rawValue: rawState),
            let startTimeTimestamp = data[Fields.startTime] as? Timestamp,
            let targetEndTimestamp = data[Fields.targetEndDate] as? Timestamp,
            let duration = doubleValue(for: data[Fields.duration]),
            let isPaused = data[Fields.isPaused] as? Bool,
            let currentRound = integerValue(for: data[Fields.currentRound]),
            let totalRounds = integerValue(for: data[Fields.totalRounds])
        else {
            return nil
        }

        let pausedBy = data[Fields.pausedBy] as? String
        let shortBreakDuration =
            doubleValue(for: data[Fields.shortBreakDuration]) ?? 5 * 60
        let longBreakDuration =
            doubleValue(for: data[Fields.longBreakDuration]) ?? 15 * 60

        return StudySession(
            id: id,
            partnerA: partnerA,
            partnerB: partnerB,
            state: state,
            startTime: startTimeTimestamp.dateValue(),
            targetEndDate: targetEndTimestamp.dateValue(),
            duration: duration,
            shortBreakDuration: shortBreakDuration,
            longBreakDuration: longBreakDuration,
            isPaused: isPaused,
            pausedBy: pausedBy,
            currentRound: currentRound,
            totalRounds: totalRounds
        )
    }

    private static func integerValue(for value: Any?) -> Int? {
        if let int = value as? Int {
            return int
        }

        if let number = value as? NSNumber {
            return number.intValue
        }

        return nil
    }

    private static func doubleValue(for value: Any?) -> Double? {
        if let double = value as? Double {
            return double
        }

        if let number = value as? NSNumber {
            return number.doubleValue
        }

        return nil
    }
}
