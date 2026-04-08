import DeviceActivity
import FamilyControls
import ManagedSettings

/// Monitors focus session intervals independently of the app process.
///
/// - ``intervalDidStart(for:)`` reapplies shields as a safety net if the
///   app was killed after scheduling but before applying restrictions.
/// - ``intervalDidEnd(for:)`` removes shields when the focus period expires,
///   even if the user force-quit PomoDuo mid-session.
///
/// The main app schedules monitoring via ``FocusActivityScheduler`` when
/// a focus session begins, and cancels it on pause, break, or completion.
///
/// - Note: The class name must match `NSExtensionPrincipalClass` in
///   `PomoDuoMonitor/Info.plist`.
class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    private let store = ManagedSettingsStore()

    // MARK: - Interval Callbacks

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)

        guard activity.rawValue == ShieldSessionContext.focusActivityID else {
            return
        }

        applyShields()
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)

        guard activity.rawValue == ShieldSessionContext.focusActivityID else {
            return
        }

        removeShields()
        ShieldSessionContext.clearSession()
    }

    // MARK: - Shield Management

    /// Reads the user's app selection from the shared App Group and
    /// applies shields via the default ``ManagedSettingsStore``.
    private func applyShields() {
        guard let selection = ShieldSessionContext.readSelection() else {
            return
        }

        let appTokens = selection.applicationTokens
        let categoryTokens = selection.categoryTokens
        let webDomainTokens = selection.webDomainTokens

        store.shield.applications = appTokens.isEmpty ? nil : appTokens
        store.shield.applicationCategories =
            categoryTokens.isEmpty ? nil : .specific(categoryTokens)
        store.shield.webDomains =
            webDomainTokens.isEmpty ? nil : webDomainTokens
        store.shield.webDomainCategories =
            categoryTokens.isEmpty ? nil : .specific(categoryTokens)
    }

    /// Removes all shields from the default ``ManagedSettingsStore``.
    private func removeShields() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        store.shield.webDomainCategories = nil
    }
}
