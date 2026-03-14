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
        /// Lightweight animation token for lock-screen icon pulse.
        ///
        /// Live Activities don't run arbitrary continuous animations reliably.
        /// Toggling this value through content updates creates a deterministic
        /// pulse effect that the system can render as state transitions.
        var pulsePhase: Bool = false
    }
}

extension TimerActivityAttributes.Phase {
    /// Upper bound for durations the current product allows users to configure.
    ///
    /// The timer settings UI only exposes presets up to these values. Live
    /// Activity rendering defensively clamps to the same bounds so a malformed
    /// persisted or remotely-sourced state cannot produce impossible compact
    /// countdowns such as multi-hour focus sessions.
    var maximumExpectedDuration: TimeInterval {
        switch self {
        case .focus:
            60 * 60
        case .shortBreak:
            10 * 60
        case .longBreak:
            30 * 60
        }
    }
}

extension TimerActivityAttributes.ContentState {
    /// Remaining seconds the UI should render for this state.
    ///
    /// Running states collapse to `0` once the deadline has elapsed, preventing
    /// timer presentations from flipping into a counting-up display.
    func remainingSecondsForDisplay(asOf referenceDate: Date = .now) -> TimeInterval {
        let cappedPhaseDuration = min(
            max(0, phaseDuration),
            phase.maximumExpectedDuration
        )
        let rawRemainingSeconds =
            isPaused
            ? pausedRemainingSeconds
            : targetEndDate.timeIntervalSince(referenceDate)

        return min(max(0, rawRemainingSeconds), cappedPhaseDuration)
    }

    /// Normalizes activity content before it is rendered or published.
    func sanitizedForDisplay(referenceDate: Date = .now) -> Self {
        let cappedPhaseDuration = min(
            max(0, phaseDuration),
            phase.maximumExpectedDuration
        )
        let remainingSeconds = remainingSecondsForDisplay(asOf: referenceDate)

        return Self(
            phase: phase,
            currentRound: currentRound,
            targetEndDate: referenceDate.addingTimeInterval(remainingSeconds),
            isPaused: isPaused,
            phaseDuration: cappedPhaseDuration,
            pausedRemainingSeconds: isPaused ? remainingSeconds : 0,
            pulsePhase: pulsePhase
        )
    }

    /// Safe countdown interval for SwiftUI timer views.
    ///
    /// Expired states collapse to a zero-length interval at `referenceDate`,
    /// which prevents any post-expiration count-up behavior.
    func countdownRange(referenceDate: Date = .now) -> ClosedRange<Date> {
        let displayState = sanitizedForDisplay(referenceDate: referenceDate)
        return referenceDate...displayState.targetEndDate
    }
}
