import Foundation

/// A snapshot of timer state emitted on each tick for the UI to render.
struct TimerTick: Sendable, Equatable {
    /// Seconds remaining in the current period.
    let remainingSeconds: TimeInterval

    /// Total duration of the current period.
    let totalDuration: TimeInterval

    /// Whether the timer is currently paused.
    let isPaused: Bool

    /// Progress from `0.0` (just started) to `1.0` (complete).
    var progress: Double {
        guard totalDuration > 0 else { return 1.0 }
        return (1.0 - (remainingSeconds / totalDuration)).clamped(to: 0...1)
    }

    /// Formatted string for display (for example, "24:59").
    var formattedTime: String {
        let totalWholeSeconds = max(0, Int(remainingSeconds.rounded(.down)))
        let minutes = totalWholeSeconds / 60
        let seconds = totalWholeSeconds % 60

        let minuteText = minutes < 10 ? "0\(minutes)" : "\(minutes)"
        let secondText = seconds < 10 ? "0\(seconds)" : "\(seconds)"
        return "\(minuteText):\(secondText)"
    }
}

extension Double {
    fileprivate func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
