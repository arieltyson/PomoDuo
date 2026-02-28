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
        /// Total duration of the current phase in seconds.
        /// Used to derive the timer interval start for the Dynamic Island progress ring.
        let phaseDuration: TimeInterval
        /// Frozen remaining seconds captured at the moment of pausing.
        /// Only meaningful when ``isPaused`` is `true`; defaults to `0` for running states.
        var pausedRemainingSeconds: TimeInterval = 0
    }
}
