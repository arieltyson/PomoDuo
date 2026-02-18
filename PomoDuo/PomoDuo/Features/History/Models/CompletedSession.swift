import Foundation
import SwiftData

/// A persisted record of a completed focus round.
@Model
final class CompletedSession {
    /// The session origin.
    enum SessionType: String, Codable, Sendable {
        case solo
        case paired
    }

    /// When the round started.
    var startedAt: Date = Date.now

    /// Focus duration in seconds.
    var focusDuration: TimeInterval = 25 * 60

    /// 1-based round index in the configured cycle.
    var roundNumber: Int = 1

    /// Total configured rounds in the cycle.
    var totalRounds: Int = 4

    /// Solo or paired completion.
    var sessionType: SessionType = SessionType.solo

    /// Local start-of-day bucket for efficient chart grouping.
    var dayBucket: Date = CompletedSession.startOfToday()

    /// The authenticated user who completed the round.
    ///
    /// `nil` for sessions recorded before user attribution existed.
    var userID: String?

    init(
        startedAt: Date = .now,
        focusDuration: TimeInterval,
        roundNumber: Int,
        totalRounds: Int,
        sessionType: SessionType = .solo,
        userID: String? = nil
    ) {
        self.startedAt = startedAt
        self.focusDuration = focusDuration
        self.roundNumber = roundNumber
        self.totalRounds = totalRounds
        self.sessionType = sessionType
        self.dayBucket = Self.startOfDay(for: startedAt)
        self.userID = userID
    }

    static func startOfDay(for date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    static func startOfToday() -> Date {
        startOfDay(for: .now)
    }

    /// Rounded down to whole minutes with a minimum of one minute.
    var focusMinutes: Int {
        max(1, Int(focusDuration / 60))
    }
}
