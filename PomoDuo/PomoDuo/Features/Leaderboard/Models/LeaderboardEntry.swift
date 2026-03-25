import Foundation

/// A single user's stats on the leaderboard.
struct LeaderboardEntry: Identifiable, Sendable, Equatable {
    let id: String
    let displayName: String
    let username: String
    let weeklyFocusMinutes: Int
    let totalFocusMinutes: Int
    let currentStreak: Int
    let isCurrentUser: Bool

    /// Rank assigned after sorting. Set externally by the view model.
    var rank: Int = 0
}
