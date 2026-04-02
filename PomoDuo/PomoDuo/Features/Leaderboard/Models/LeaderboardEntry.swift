import Foundation

/// A single user's stats on the leaderboard.
struct LeaderboardEntry: Identifiable, Sendable, Equatable {
    let id: String
    let displayName: String
    let username: String
    let dailyFocusMinutes: Int
    let weeklyFocusMinutes: Int
    let totalFocusMinutes: Int
    let currentStreak: Int
    let isCurrentUser: Bool

    /// Rank assigned after sorting. Set externally by the view model.
    var rank: Int = 0

    /// Focus total to present for the selected leaderboard period.
    func focusMinutes(for period: LeaderboardPeriod) -> Int {
        switch period {
        case .today:
            dailyFocusMinutes
        case .thisWeek:
            weeklyFocusMinutes
        case .allTime:
            totalFocusMinutes
        }
    }
}
