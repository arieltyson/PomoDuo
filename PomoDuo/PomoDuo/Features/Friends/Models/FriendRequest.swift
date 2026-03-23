import Foundation

/// A pending friend request between two users.
struct FriendRequest: Sendable, Equatable, Codable, Identifiable {
    /// Firestore document ID.
    let id: String
    /// UID of the sender.
    let fromUID: String
    /// Display name of the sender.
    let fromDisplayName: String
    /// Username of the sender.
    let fromUsername: String
    /// UID of the receiver.
    let toUID: String
    /// Current status of the request.
    let status: FriendRequestStatus
    /// When the request was created.
    let createdAt: Date
}
