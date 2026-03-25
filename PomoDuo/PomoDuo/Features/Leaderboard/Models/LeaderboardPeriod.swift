import Foundation

/// Time period for leaderboard ranking.
enum LeaderboardPeriod: String, CaseIterable, Identifiable, Sendable {
    case thisWeek
    case allTime

    nonisolated var id: String { rawValue }

    var title: String {
        switch self {
        case .thisWeek:
            "This Week"
        case .allTime:
            "All Time"
        }
    }
}
