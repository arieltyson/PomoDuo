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

    /// Regression: a slow earlier search that finishes after a newer search
    /// must not overwrite the newer result.
    ///
    /// The `RaceableSearchFriendService` makes `"slow"` take 200 ms and
    /// `"fast"` return immediately, so a correctly-behaving newest-wins
    /// implementation cancels the slow call and rejects its late write.
    @Test func searchNewestQueryWinsOverSlowerEarlierCall() async {
        let service = RaceableSearchFriendService()
        let viewModel = FriendsViewModel(friendService: service)

        viewModel.searchQuery = "slow"
        async let slowCall: Void = viewModel.searchForUser()

        // Let the slow call enter its service await before the fast call
        // cancels it. `Task.yield` is a scheduler hint, not a sleep — it's
        // deterministic with the actor-local execution model here.
        await Task.yield()

        viewModel.searchQuery = "fast"
        await viewModel.searchForUser()

        // Drain the cancelled slow call so we observe the post-cancellation
        // steady state rather than a mid-cancellation snapshot.
        await slowCall

        #expect(viewModel.searchResult?.username == "fast")
        #expect(viewModel.searchFoundNoResults == false)
        #expect(viewModel.isSearching == false)
        #expect(viewModel.error == nil)
    }

    /// Regression: even when the slow earlier search ultimately returns a
    /// *matching* result, its write must still be rejected if a newer
    /// search has taken ownership.
    @Test func searchCancelsIgnoresSlowSuccessAfterNewerCall() async {
        let service = RaceableSearchFriendService()
        let viewModel = FriendsViewModel(friendService: service)

        viewModel.searchQuery = "slow"
        async let slowCall: Void = viewModel.searchForUser()
        await Task.yield()

        viewModel.searchQuery = "not-found"
        await viewModel.searchForUser()

        await slowCall

        // The fast query resolves to nil (no match). The slow call's
        // eventual success result must not resurrect `searchResult`.
        #expect(viewModel.searchResult == nil)
        #expect(viewModel.searchFoundNoResults == true)
        #expect(viewModel.isSearching == false)
    }

    /// Regression: `sendFriendRequest` must ignore a second call while one
    /// is already in flight so the backend never sees duplicate writes for
    /// a double-tap that slips past the Button's `disabled` binding.
    @Test func sendFriendRequestIgnoresConcurrentCalls() async {
        let service = CountingSendFriendService()
        let viewModel = FriendsViewModel(friendService: service)

        viewModel.forceSearchResultForTests(
            UserSearchResult(
                id: "friend-1",
                displayName: "Study Buddy",
                username: "buddy"
            )
        )

        // Start the first send, let it enter the service's await so
        // `isSendingRequest` flips to `true`, then fire the second call —
        // the `!isSendingRequest` guard must reject it, leaving the
        // server-side `callCount` at exactly one.
        async let firstSend: Void = viewModel.sendFriendRequest()
        await Task.yield()

        await viewModel.sendFriendRequest()
        await firstSend

        #expect(service.callCount == 1)
        #expect(viewModel.isSendingRequest == false)
        #expect(viewModel.searchResult == nil)
        #expect(viewModel.searchQuery == "")
    }

    /// Regression: signing out must tear down not just the observation
    /// streams but also every piece of derived user state so a subsequent
    /// sign-in with a different identity starts from a clean baseline.
    @Test func stopObservingClearsSearchAndUsernameSetupState() async {
        let service = StubFriendService()
        let viewModel = FriendsViewModel(friendService: service)

        viewModel.startObserving(displayName: "Old Name")
        await viewModel.waitForCurrentUsernameFetchForTests()
        viewModel.searchQuery = "buddy"
        await viewModel.searchForUser()
        viewModel.usernameInput = "old_handle"
        viewModel.forceSearchResultForTests(
            UserSearchResult(
                id: "friend-1",
                displayName: "Stale",
                username: "stale"
            )
        )
        viewModel.highlightedRequestID = "req-1"

        viewModel.stopObserving()

        #expect(viewModel.friends.isEmpty)
        #expect(viewModel.incomingRequests.isEmpty)
        #expect(viewModel.currentUsername == nil)
        #expect(viewModel.highlightedRequestID == nil)
        #expect(viewModel.searchQuery == "")
        #expect(viewModel.searchResult == nil)
        #expect(viewModel.searchFoundNoResults == false)
        #expect(viewModel.isSearching == false)
        #expect(viewModel.isSendingRequest == false)
        #expect(viewModel.error == nil)
        #expect(viewModel.usernameInput == "")
        #expect(viewModel.isUsernameAvailable == nil)
        #expect(viewModel.isCheckingAvailability == false)
        #expect(viewModel.isClaimingUsername == false)
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

/// Search stub that lets the test drive an out-of-order completion:
/// `"slow"` intentionally lags behind `"fast"`, so a broken newest-wins
/// policy would overwrite the fast result with the slow one.
///
/// The `"slow"` branch still returns a *successful* result (when not
/// cancelled) so we also cover the case where the stale write would look
/// legitimate in isolation.
@MainActor
private final class RaceableSearchFriendService: FriendService, @unchecked Sendable {
    nonisolated func friendsStream() -> AsyncStream<[FriendProfile]> {
        AsyncStream { $0.finish() }
    }

    nonisolated func incomingRequestsStream() -> AsyncStream<[FriendRequest]> {
        AsyncStream { $0.finish() }
    }

    nonisolated func currentUsername() async throws -> String? { nil }

    nonisolated func searchByUsername(
        _ username: String
    ) async throws -> UserSearchResult? {
        switch username {
        case "slow":
            try? await Task.sleep(for: .milliseconds(200))
            if Task.isCancelled { return nil }
            return UserSearchResult(
                id: "slow-id",
                displayName: "Slow User",
                username: "slow"
            )
        case "fast":
            return UserSearchResult(
                id: "fast-id",
                displayName: "Fast User",
                username: "fast"
            )
        default:
            return nil
        }
    }

    nonisolated func isUsernameAvailable(_ username: String) async throws -> Bool { true }
    nonisolated func claimUsername(_ username: String) async throws -> Bool { true }
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

/// Send stub that records invocation count and yields briefly so the
/// caller's `isSendingRequest` latch has time to flip before the test
/// fires a concurrent second send.
@MainActor
private final class CountingSendFriendService: FriendService, @unchecked Sendable {
    private(set) var callCount = 0

    nonisolated func sendFriendRequest(toUsername username: String) async throws {
        await MainActor.run { self.callCount += 1 }
        try? await Task.sleep(for: .milliseconds(50))
    }

    nonisolated func friendsStream() -> AsyncStream<[FriendProfile]> {
        AsyncStream { $0.finish() }
    }
    nonisolated func incomingRequestsStream() -> AsyncStream<[FriendRequest]> {
        AsyncStream { $0.finish() }
    }
    nonisolated func currentUsername() async throws -> String? { nil }
    nonisolated func isUsernameAvailable(_ username: String) async throws -> Bool { true }
    nonisolated func claimUsername(_ username: String) async throws -> Bool { true }
    nonisolated func searchByUsername(_ username: String) async throws -> UserSearchResult? { nil }
    nonisolated func acceptFriendRequest(_ requestID: String) async throws {}
    nonisolated func declineFriendRequest(_ requestID: String) async throws {}
    nonisolated func removeFriend(_ friendID: String) async throws {}
    nonisolated func friends() async throws -> [FriendProfile] { [] }
    nonisolated func reportFocusSession(minutes: Int) async throws {}
    nonisolated func leaderboardEntries() async throws -> [LeaderboardEntry] { [] }
    nonisolated func propagateDisplayName(_ newName: String) async throws {}
    nonisolated func deleteAccountData() async throws {}
}
