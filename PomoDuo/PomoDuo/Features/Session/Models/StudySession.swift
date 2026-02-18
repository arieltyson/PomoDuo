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
    var isPaused: Bool
    var pausedBy: String?
    var currentRound: Int
    var totalRounds: Int

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
}
