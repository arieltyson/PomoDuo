import Foundation

/// A confirmed friendship between two users.
struct FriendProfile: Sendable, Equatable, Codable, Identifiable {
    /// The friend's user ID.
    let id: String
    /// Human-readable name for display.
    let displayName: String
    /// Unique handle for discovery.
    let username: String
    /// When the friendship was established.
    let friendsSince: Date
}
