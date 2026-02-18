import Foundation

/// Abstracts app restriction behavior so the session logic
/// does not depend directly on the Screen Time framework.
protocol RestrictionService: Sendable {
    /// Blocks the user's selected distracting apps.
    func applyRestrictions() async throws

    /// Removes all app restrictions.
    func removeRestrictions() async throws

    /// Whether the user has granted Screen Time authorization.
    var isAuthorized: Bool { get async }
}
