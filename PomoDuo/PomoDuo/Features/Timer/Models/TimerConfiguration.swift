//
//  TimerConfiguration.swift
//  PomoDuo
//
//  Created by Codex on 2/15/26.
//

import Foundation
import SwiftData

/// Persisted timer settings that the user can customize.
/// Stored locally with SwiftData and never synced to the backend.
@Model
final class TimerConfiguration {
    /// Focus period duration in seconds.
    var focusDuration: TimeInterval

    /// Short break duration in seconds.
    var shortBreakDuration: TimeInterval

    /// Long break duration in seconds.
    var longBreakDuration: TimeInterval

    /// Number of focus rounds before a long break.
    var roundsBeforeLongBreak: Int

    init(
        focusDuration: TimeInterval = 25 * 60,
        shortBreakDuration: TimeInterval = 5 * 60,
        longBreakDuration: TimeInterval = 15 * 60,
        roundsBeforeLongBreak: Int = 4
    ) {
        self.focusDuration = focusDuration
        self.shortBreakDuration = shortBreakDuration
        self.longBreakDuration = longBreakDuration
        self.roundsBeforeLongBreak = roundsBeforeLongBreak
    }
}

extension TimerConfiguration {
    /// Preset durations (in seconds) for focus periods.
    static let focusPresets: [TimeInterval] = [15, 20, 25, 30, 45, 60].map { TimeInterval($0 * 60) }

    /// Preset durations (in seconds) for short breaks.
    static let shortBreakPresets: [TimeInterval] = [3, 5, 10].map { TimeInterval($0 * 60) }

    /// Preset durations (in seconds) for long breaks.
    static let longBreakPresets: [TimeInterval] = [10, 15, 20, 30].map { TimeInterval($0 * 60) }

    /// Preset round-count options before a long break.
    static let roundPresets: [Int] = [2, 3, 4, 5, 6]

    /// Formats a duration in seconds to a human-readable label.
    static func formatted(duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        return "\(minutes) min"
    }
}
