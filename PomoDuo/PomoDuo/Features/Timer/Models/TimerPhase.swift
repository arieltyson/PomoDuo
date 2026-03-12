import Foundation

/// The current phase of the solo timer flow.
nonisolated enum TimerPhase: String, Codable, Sendable {
    case idle
    case focus
    case shortBreak
    case longBreak

    var isBreak: Bool {
        switch self {
        case .shortBreak, .longBreak:
            true
        case .idle, .focus:
            false
        }
    }

    var title: String {
        switch self {
        case .idle:
            "Ready"
        case .focus:
            "Focus"
        case .shortBreak:
            "Short Break"
        case .longBreak:
            "Long Break"
        }
    }

    var activityPhase: TimerActivityAttributes.Phase {
        switch self {
        case .idle, .focus:
            .focus
        case .shortBreak:
            .shortBreak
        case .longBreak:
            .longBreak
        }
    }
}
