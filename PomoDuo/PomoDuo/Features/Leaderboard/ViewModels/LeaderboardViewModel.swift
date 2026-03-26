import Foundation
import Observation
import OSLog

/// Observable state and intents for the friends leaderboard.
@MainActor
@Observable
final class LeaderboardViewModel {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.arieljtyson.PomoDuo",
        category: "LeaderboardViewModel"
    )

    /// Active time period for ranking.
    var period = LeaderboardPeriod.today

    /// Ranked leaderboard entries.
    private(set) var entries: [LeaderboardEntry] = []

    /// Whether the leaderboard is loading.
    private(set) var isLoading = false

    /// User-facing error message.
    private(set) var error: String?

    private let friendService: any FriendService

    init(friendService: any FriendService) {
        self.friendService = friendService
    }

    func refresh() async {
        isLoading = true
        error = nil

        do {
            let raw = try await friendService.leaderboardEntries()
            entries = ranked(raw)
        } catch {
            Self.logger.error("Leaderboard fetch failed: \(error.localizedDescription, privacy: .public)")
            self.error = "Could not load leaderboard."
        }

        isLoading = false
    }

    func dismissError() {
        error = nil
    }

    /// Sorts entries by the active period's metric and assigns ranks.
    private func ranked(_ entries: [LeaderboardEntry]) -> [LeaderboardEntry] {
        let sorted = entries.sorted { lhs, rhs in
            sortValue(for: lhs) > sortValue(for: rhs)
        }

        return sorted.enumerated().map { index, entry in
            var ranked = entry
            ranked.rank = index + 1
            return ranked
        }
    }

    private func sortValue(for entry: LeaderboardEntry) -> Int {
        switch period {
        case .today:
            entry.dailyFocusMinutes
        case .thisWeek:
            entry.weeklyFocusMinutes
        case .allTime:
            entry.totalFocusMinutes
        }
    }
}
