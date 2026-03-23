import Foundation

/// Outcome of local username format validation.
enum UsernameValidationResult: Sendable, Equatable {
    case valid
    case tooShort
    case tooLong
    case invalidCharacters
    case empty

    /// Minimum allowed username length.
    static let minLength = 3
    /// Maximum allowed username length.
    static let maxLength = 20

    var errorMessage: String? {
        switch self {
        case .valid:
            nil
        case .tooShort:
            "Username must be at least \(Self.minLength) characters."
        case .tooLong:
            "Username must be \(Self.maxLength) characters or fewer."
        case .invalidCharacters:
            "Only letters, numbers, and underscores are allowed."
        case .empty:
            nil
        }
    }
}
