import Foundation

/// Backend abstraction for friend operations.
protocol FriendService: Sendable {
    /// Sends a friend request to the user with the given username.
    func sendFriendRequest(toUsername username: String) async throws

    /// Accepts an incoming friend request.
    func acceptFriendRequest(_ requestID: String) async throws

    /// Declines an incoming friend request.
    func declineFriendRequest(_ requestID: String) async throws

    /// Removes an existing friendship.
    func removeFriend(_ friendUID: String) async throws

    /// Returns a one-shot snapshot of the current user's friends.
    func friends() async throws -> [FriendProfile]

    /// Streams real-time updates to incoming friend requests.
    func incomingRequestsStream() -> AsyncStream<[FriendRequest]>

    /// Streams real-time updates to the friends list.
    func friendsStream() -> AsyncStream<[FriendProfile]>

    /// Claims a username for the current user.
    func claimUsername(_ username: String) async throws -> Bool

    /// Checks whether a username is available.
    func isUsernameAvailable(_ username: String) async throws -> Bool

    /// Returns the current user's username, if set.
    func currentUsername() async throws -> String?

    /// Searches for a user by exact username match.
    func searchByUsername(_ username: String) async throws -> UserSearchResult?

    // MARK: - Leaderboard

    /// Reports completed focus minutes to the user's Firestore profile
    /// so friends can see aggregated stats on the leaderboard.
    func reportFocusSession(minutes: Int) async throws

    /// Fetches leaderboard entries for the current user and all friends.
    func leaderboardEntries() async throws -> [LeaderboardEntry]
}
