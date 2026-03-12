import Foundation

/// Persisted solo timer state used to restore an interrupted session.
nonisolated struct SoloTimerSessionSnapshot: Codable, Equatable, Sendable {
    enum Status: String, Codable, Sendable {
        case running
        case paused
        case awaitingContinuation
    }

    let phase: TimerPhase
    let currentRound: Int
    let focusStartedAt: Date?
    let targetEndDate: Date
    let phaseDuration: TimeInterval
    let status: Status
    let pausedRemainingSeconds: TimeInterval

    init(
        phase: TimerPhase,
        currentRound: Int,
        focusStartedAt: Date?,
        targetEndDate: Date,
        phaseDuration: TimeInterval,
        status: Status,
        pausedRemainingSeconds: TimeInterval
    ) {
        self.phase = phase
        self.currentRound = currentRound
        self.focusStartedAt = focusStartedAt
        self.targetEndDate = targetEndDate
        self.phaseDuration = phaseDuration
        self.status = status
        self.pausedRemainingSeconds = pausedRemainingSeconds
    }

    static func == (
        lhs: SoloTimerSessionSnapshot,
        rhs: SoloTimerSessionSnapshot
    ) -> Bool {
        lhs.phase == rhs.phase
            && lhs.currentRound == rhs.currentRound
            && lhs.focusStartedAt == rhs.focusStartedAt
            && lhs.targetEndDate == rhs.targetEndDate
            && lhs.phaseDuration == rhs.phaseDuration
            && lhs.status == rhs.status
            && lhs.pausedRemainingSeconds == rhs.pausedRemainingSeconds
    }
}
