import Foundation

/// Typed errors for friend operations, enabling user-facing messages.
enum FriendServiceError: LocalizedError, Sendable {
    case userNotFound
    case cannotAddSelf
    case alreadyFriends
    case requestAlreadySent

    var errorDescription: String? {
        switch self {
        case .userNotFound:
            "That user could not be found. Check the username and try again."
        case .cannotAddSelf:
            "You cannot send a friend request to yourself."
        case .alreadyFriends:
            "You are already friends with this user."
        case .requestAlreadySent:
            "A friend request has already been sent to this user."
        }
    }
}
