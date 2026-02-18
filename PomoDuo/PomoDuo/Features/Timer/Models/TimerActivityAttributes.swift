import ActivityKit
import Foundation

/// Shared ActivityKit attributes for the PomoDuo timer Live Activity.
struct TimerActivityAttributes: ActivityAttributes {
    /// The timer phase shown in the Live Activity.
    enum Phase: String, Codable, Hashable, Sendable {
        case focus
        case shortBreak
        case longBreak

        var label: String {
            switch self {
            case .focus:
                "Focus"
            case .shortBreak:
                "Short Break"
            case .longBreak:
                "Long Break"
            }
        }

        var systemImage: String {
            switch self {
            case .focus:
                "brain.head.profile"
            case .shortBreak:
                "cup.and.saucer.fill"
            case .longBreak:
                "figure.walk"
            }
        }

        var isBreak: Bool {
            self != .focus
        }
    }

    /// Total rounds in the current session.
    let totalRounds: Int

    /// Dynamic Live Activity state.
    struct ContentState: Codable, Hashable, Sendable {
        let phase: Phase
        let currentRound: Int
        let targetEndDate: Date
        let isPaused: Bool
    }
}
