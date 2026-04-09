import Foundation
import Testing

@testable import PomoDuo

@MainActor
struct FriendsViewModelLifecycleTests {

    @Test func stopObservingCancelsUsernameTask() async {
        let service = StubFriendService()
        let viewModel = FriendsViewModel(friendService: service)

        viewModel.startObserving(displayName: "Test")

        // The username fetch task is now in-flight.
        // Stop before it can complete.
        viewModel.stopObserving()

        // Allow any in-flight work to settle.
        try? await Task.sleep(for: .milliseconds(100))

        // After stopObserving, currentUsername must remain nil
        // even though the stub would return "testuser".
        #expect(viewModel.currentUsername == nil)
    }

    @Test func startObservingPopulatesUsername() async {
        let service = StubFriendService()
        let viewModel = FriendsViewModel(friendService: service)

        viewModel.startObserving(displayName: "Test")

        // Allow the username fetch to complete.
        try? await Task.sleep(for: .milliseconds(100))

        #expect(viewModel.currentUsername == "testuser")
    }

    @Test func restartObservingCancelsPreviousUsernameFetch() async {
        let service = SlowFriendService()
        let viewModel = FriendsViewModel(friendService: service)

        // Start with a slow service — username fetch takes 500ms.
        viewModel.startObserving(displayName: "First")

        // Immediately restart — should cancel the first fetch.
        viewModel.startObserving(displayName: "Second")

        // Wait for the second fetch to complete.
        try? await Task.sleep(for: .milliseconds(600))

        // Should have the result from the second call, not stale data.
        #expect(viewModel.currentUsername == "testuser")
        #expect(viewModel.currentDisplayName == "Second")
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
