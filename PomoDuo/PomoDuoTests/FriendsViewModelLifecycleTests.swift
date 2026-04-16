import Foundation
import Testing

@testable import PomoDuo

@MainActor
struct FriendsViewModelLifecycleTests {

    @Test func stopObservingCancelsUsernameTask() async {
        let service = StubFriendService()
        let viewModel = FriendsViewModel(friendService: service)

        viewModel.startObserving(displayName: "Test")
        // Stop before the fetch can complete. `stopObserving` cancels the
        // in-flight task and nils it out, so the deterministic wait just
        // observes that there is nothing left to drain.
        viewModel.stopObserving()
        await viewModel.waitForCurrentUsernameFetchForTests()

        // After stopObserving, currentUsername must remain nil
        // even though the stub would return "testuser".
        #expect(viewModel.currentUsername == nil)
    }

    @Test func startObservingPopulatesUsername() async {
        let service = StubFriendService()
        let viewModel = FriendsViewModel(friendService: service)

        viewModel.startObserving(displayName: "Test")
        await viewModel.waitForCurrentUsernameFetchForTests()

        #expect(viewModel.currentUsername == "testuser")
    }

    @Test func restartObservingCancelsPreviousUsernameFetch() async {
        let service = SlowFriendService()
        let viewModel = FriendsViewModel(friendService: service)

        // First fetch is slow (500ms in `SlowFriendService`).
        viewModel.startObserving(displayName: "First")

        // Immediately restart — the first fetch is cancelled, the second is
        // the only one allowed to write back to `currentUsername`.
        viewModel.startObserving(displayName: "Second")

        // Deterministically wait for the second fetch to finish, instead of
        // racing a sleep threshold against main-actor contention in CI.
        await viewModel.waitForCurrentUsernameFetchForTests()

        // Should have the result from the second call, not stale data.
        #expect(viewModel.currentUsername == "testuser")
        #expect(viewModel.currentDisplayName == "Second")
    }

    /// Regression: after the auth fix made same-identity profile updates
    /// deterministic, Partner share/invite surfaces must reflect a renamed
    /// user without tearing down the friends/requests/username streams.
    @Test func updateDisplayNameRefreshesWithoutRestartingObservation() async {
        let service = StubFriendService()
        let viewModel = FriendsViewModel(friendService: service)

        viewModel.startObserving(displayName: "Old Name")
        await viewModel.waitForCurrentUsernameFetchForTests()
        #expect(viewModel.currentUsername == "testuser")
        #expect(viewModel.currentDisplayName == "Old Name")

        viewModel.updateDisplayName("New Name")

        // The observer pipeline must not have been torn down — the
        // already-fetched username is still present — and the invite/share
        // display name must reflect the rename.
        #expect(viewModel.currentUsername == "testuser")
        #expect(viewModel.currentDisplayName == "New Name")
    }
}

// MARK: - Test Doubles

@MainActor
private final class StubFriendService: FriendService, @unchecked Sendable {
    nonisolated func friendsStream() -> AsyncStream<[FriendProfile]> {
        AsyncStream { $0.finish() }
    }

    nonisolated func incomingRequestsStream() -> AsyncStream<[FriendRequest]> {
        AsyncStream { $0.finish() }
    }

    nonisolated func currentUsername() async throws -> String? {
        "testuser"
    }

    nonisolated func isUsernameAvailable(_ username: String) async throws -> Bool { true }
    nonisolated func claimUsername(_ username: String) async throws -> Bool { true }
    nonisolated func searchByUsername(_ username: String) async throws -> UserSearchResult? { nil }
    nonisolated func sendFriendRequest(toUsername username: String) async throws {}
    nonisolated func acceptFriendRequest(_ requestID: String) async throws {}
    nonisolated func declineFriendRequest(_ requestID: String) async throws {}
    nonisolated func removeFriend(_ friendID: String) async throws {}
    nonisolated func friends() async throws -> [FriendProfile] { [] }
    nonisolated func reportFocusSession(minutes: Int) async throws {}
    nonisolated func leaderboardEntries() async throws -> [LeaderboardEntry] { [] }
    nonisolated func propagateDisplayName(_ newName: String) async throws {}
    nonisolated func deleteAccountData() async throws {}
}

@MainActor
private final class SlowFriendService: FriendService, @unchecked Sendable {
    nonisolated func friendsStream() -> AsyncStream<[FriendProfile]> {
        AsyncStream { $0.finish() }
    }

    nonisolated func incomingRequestsStream() -> AsyncStream<[FriendRequest]> {
        AsyncStream { $0.finish() }
    }

    nonisolated func currentUsername() async throws -> String? {
        try? await Task.sleep(for: .milliseconds(500))
        return Task.isCancelled ? nil : "testuser"
    }

    nonisolated func isUsernameAvailable(_ username: String) async throws -> Bool { true }
    nonisolated func claimUsername(_ username: String) async throws -> Bool { true }
    nonisolated func searchByUsername(_ username: String) async throws -> UserSearchResult? { nil }
    nonisolated func sendFriendRequest(toUsername username: String) async throws {}
    nonisolated func acceptFriendRequest(_ requestID: String) async throws {}
    nonisolated func declineFriendRequest(_ requestID: String) async throws {}
    nonisolated func removeFriend(_ friendID: String) async throws {}
    nonisolated func friends() async throws -> [FriendProfile] { [] }
    nonisolated func reportFocusSession(minutes: Int) async throws {}
    nonisolated func leaderboardEntries() async throws -> [LeaderboardEntry] { [] }
    nonisolated func propagateDisplayName(_ newName: String) async throws {}
    nonisolated func deleteAccountData() async throws {}
}
