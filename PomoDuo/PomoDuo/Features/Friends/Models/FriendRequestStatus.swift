import Foundation

/// Lifecycle state of a friend request.
enum FriendRequestStatus: String, Codable, Sendable {
    case pending
    case accepted
    case declined
}
