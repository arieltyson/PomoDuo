import Foundation

/// Every possible state of a shared PomoDuo study session.
enum SessionState: String, Codable, Sendable {
    /// No active session.
    case idle
    /// Partner A has requested a session, waiting for Partner B.
    case requesting
    /// Active focus period. Apps are blocked and timer is counting down.
    case focus
    /// Short break between focus rounds.
    case shortBreak
    /// Long break after completing all rounds.
    case longBreak
    /// Session fully completed.
    case completed
}
