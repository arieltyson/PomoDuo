import Observation
import UIKit

/// Routes Home Screen quick actions into the SwiftUI layer.
@MainActor
@Observable
final class QuickActionManager {
    /// The latest quick action waiting to be handled by the UI.
    private(set) var pendingAction: QuickAction?

    /// Handles a shortcut item received by ``AppDelegate``.
    /// - Returns: `true` when the item is a known quick action.
    @discardableResult
    func handle(_ shortcutItem: UIApplicationShortcutItem) -> Bool {
        guard let action = QuickAction(shortcutItem: shortcutItem) else {
            return false
        }

        pendingAction = action
        return true
    }

    /// Returns and clears the current pending action.
    @discardableResult
    func consumePendingAction() -> QuickAction? {
        defer { pendingAction = nil }
        return pendingAction
    }
}
