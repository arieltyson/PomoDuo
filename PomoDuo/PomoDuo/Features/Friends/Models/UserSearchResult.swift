import Foundation

/// A user found via username search.
struct UserSearchResult: Sendable, Equatable, Identifiable {
    let id: String
    let displayName: String
    let username: String
}
