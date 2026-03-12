import Foundation

/// The shared source of truth for a PomoDuo study session.
/// Both devices derive their local state from this single structure.
struct StudySession: Codable, Sendable, Identifiable, Equatable {
    let id: String
    let partnerA: String
    let partnerB: String
    var state: SessionState
    var startTime: Date
    /// The absolute time the current period (focus or break) ends.
    /// Both devices calculate their countdown from this value, which removes per-tick syncing.
    var targetEndDate: Date
    /// The configured focus duration in seconds (for example, 1500 for 25 minutes).
    /// Used to compute `targetEndDate` on state transitions.
    var duration: TimeInterval
    /// The configured short-break duration in seconds.
    var shortBreakDuration: TimeInterval
    /// The configured long-break duration in seconds.
    var longBreakDuration: TimeInterval
    var isPaused: Bool
    var pausedBy: String?
    var currentRound: Int
    var totalRounds: Int

    nonisolated init(
        id: String,
        partnerA: String,
        partnerB: String,
        state: SessionState,
        startTime: Date,
        targetEndDate: Date,
        duration: TimeInterval,
        shortBreakDuration: TimeInterval = 5 * 60,
        longBreakDuration: TimeInterval = 15 * 60,
        isPaused: Bool,
        pausedBy: String?,
        currentRound: Int,
        totalRounds: Int
    ) {
        self.id = id
        self.partnerA = partnerA
        self.partnerB = partnerB
        self.state = state
        self.startTime = startTime
        self.targetEndDate = targetEndDate
        self.duration = duration
        self.shortBreakDuration = shortBreakDuration
        self.longBreakDuration = longBreakDuration
        self.isPaused = isPaused
        self.pausedBy = pausedBy
        self.currentRound = currentRound
        self.totalRounds = totalRounds
    }

    /// Returns whether the given user ID is a member of this session.
    func isMember(_ userID: String) -> Bool {
        userID == partnerA || userID == partnerB
    }

    /// Returns the partner's user ID for a given session member.
    func partnerID(for userID: String) -> String? {
        switch userID {
        case partnerA:
            partnerB
        case partnerB:
            partnerA
        default:
            nil
        }
    }

    /// Returns the expected duration for the session's current phase.
    var currentPhaseDuration: TimeInterval {
        switch state {
        case .shortBreak:
            shortBreakDuration
        case .longBreak:
            longBreakDuration
        case .idle, .requesting, .focus, .completed:
            duration
        }
    }

    /// Returns `true` when the current timed phase has already elapsed.
    func hasReachedPhaseEnd(asOf date: Date = .now) -> Bool {
        guard supportsCountdown else {
            return false
        }

        return !isPaused && targetEndDate <= date
    }

    /// Returns `true` when the session represents a timed phase.
    var supportsCountdown: Bool {
        switch state {
        case .focus, .shortBreak, .longBreak:
            true
        case .idle, .requesting, .completed:
            false
        }
    }
}
