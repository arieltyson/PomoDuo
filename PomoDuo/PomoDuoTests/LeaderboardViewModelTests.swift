import Testing

@testable import PomoDuo

@Suite("LeaderboardViewModel")
@MainActor
struct LeaderboardViewModelTests {
    @Test("Refresh ranks entries using the selected period")
    func refreshRanksEntriesUsingSelectedPeriod() async {
        let viewModel = LeaderboardViewModel(
            friendService: LeaderboardServiceStub(
                entries: [
                    LeaderboardEntry(
                        id: "alpha",
                        displayName: "Alpha",
                        username: "alpha",
                        dailyFocusMinutes: 20,
                        weeklyFocusMinutes: 90,
                        totalFocusMinutes: 500,
                        currentStreak: 2,
                        isCurrentUser: false
                    ),
                    LeaderboardEntry(
                        id: "beta",
                        displayName: "Beta",
                        username: "beta",
                        dailyFocusMinutes: 35,
                        weeklyFocusMinutes: 60,
                        totalFocusMinutes: 900,
                        currentStreak: 4,
                        isCurrentUser: true
                    ),
                    LeaderboardEntry(
                        id: "gamma",
                        displayName: "Gamma",
                        username: "gamma",
                        dailyFocusMinutes: 10,
                        weeklyFocusMinutes: 120,
                        totalFocusMinutes: 300,
                        currentStreak: 0,
                        isCurrentUser: false
                    )
                ]
            )
        )

        viewModel.period = .thisWeek

        await viewModel.refresh()

        #expect(viewModel.entries.map(\.id) == ["gamma", "alpha", "beta"])
        #expect(viewModel.entries.map(\.rank) == [1, 2, 3])
    }

    @Test("LeaderboardEntry returns the correct minutes for each period")
    func focusMinutesForPeriod() {
        let entry = LeaderboardEntry(
            id: "entry",
            displayName: "Focus Friend",
            username: "focusfriend",
            dailyFocusMinutes: 25,
            weeklyFocusMinutes: 140,
            totalFocusMinutes: 860,
            currentStreak: 6,
            isCurrentUser: false
        )

        #expect(entry.focusMinutes(for: .today) == 25)
        #expect(entry.focusMinutes(for: .thisWeek) == 140)
        #expect(entry.focusMinutes(for: .allTime) == 860)
    }
}

private struct LeaderboardServiceStub: FriendService {
    let entries: [LeaderboardEntry]

    func sendFriendRequest(toUsername username: String) async throws {}
    func acceptFriendRequest(_ requestID: String) async throws {}
    func declineFriendRequest(_ requestID: String) async throws {}
    func removeFriend(_ friendUID: String) async throws {}
    func friends() async throws -> [FriendProfile] { [] }
    func incomingRequestsStream() -> AsyncStream<[FriendRequest]> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }
    func friendsStream() -> AsyncStream<[FriendProfile]> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }
    func claimUsername(_ username: String) async throws -> Bool { true }
    func isUsernameAvailable(_ username: String) async throws -> Bool { true }
    func currentUsername() async throws -> String? { nil }
    func searchByUsername(_ username: String) async throws -> UserSearchResult? { nil }
    func reportFocusSession(minutes: Int) async throws {}
    func leaderboardEntries() async throws -> [LeaderboardEntry] { entries }
    func deleteAccountData() async throws {}
}
