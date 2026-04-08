import Foundation

/// No-op implementation of ``FriendService`` for previews and tests.
struct MockFriendService: FriendService {
    func sendFriendRequest(toUsername username: String) async throws {}
    func acceptFriendRequest(_ requestID: String) async throws {}
    func declineFriendRequest(_ requestID: String) async throws {}
    func removeFriend(_ friendUID: String) async throws {}
    func friends() async throws -> [FriendProfile] { [] }
    func incomingRequestsStream() -> AsyncStream<[FriendRequest]> {
        AsyncStream { $0.finish() }
    }
    func friendsStream() -> AsyncStream<[FriendProfile]> {
        AsyncStream { $0.finish() }
    }
    func claimUsername(_ username: String) async throws -> Bool { true }
    func isUsernameAvailable(_ username: String) async throws -> Bool { true }
    func currentUsername() async throws -> String? { nil }
    func searchByUsername(_ username: String) async throws -> UserSearchResult? { nil }
    func reportFocusSession(minutes: Int) async throws {}
    func leaderboardEntries() async throws -> [LeaderboardEntry] { [] }
    func propagateDisplayName(_ newName: String) async throws {}
    func deleteAccountData() async throws {}
}
