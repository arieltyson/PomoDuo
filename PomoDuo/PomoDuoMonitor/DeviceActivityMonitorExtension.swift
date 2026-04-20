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

        // See ``ShieldSessionContext/hasUnexpiredTargetEnd(asOf:)`` for
        // the full rationale: iOS fires `intervalDidEnd` *also* when
        // the main app calls `DeviceActivityCenter.stopMonitoring(_:)`
        // to replace the prior registration during a reconcile /
        // reschedule. Tearing down shields + shared context on those
        // spurious ends desyncs the live session. If the session's
        // target end is still in the future we treat this callback as
        // a reschedule and leave the shared state alone; the matching
        // `intervalDidStart` will reapply shields either way.
        guard !ShieldSessionContext.hasUnexpiredTargetEnd() else {
            return
        }

        removeShields()
        ShieldSessionContext.clearSession()
    }

    // MARK: - Shield Management

    /// Reads the user's app selection from the shared App Group and applies
    /// shields via the same ``ShieldPolicyMapper`` the main app uses.
    ///
    /// Sharing the mapper guarantees the extension's re-application
    /// after a force-quit produces byte-identical shield writes.
    private func applyShields() {
        guard let selection = ShieldSessionContext.readSelection() else {
            return
        }

        let categoryTokens = ShieldSessionContext
            .readShieldedCategoryTokens() ?? selection.categoryTokens
        let decision = ShieldPolicyMapper.decide(
            applicationTokens: selection.applicationTokens,
            categoryTokens: categoryTokens,
            webDomainTokens: selection.webDomainTokens,
            categoryExceptions:
                ShieldSessionContext.readCategoryExceptions() ?? [],
            webDomainCategoryExceptions:
                ShieldSessionContext.readWebDomainCategoryExceptions() ?? []
        )

        ShieldPolicyMapper.apply(decision, to: store)
    }

    /// Removes all shields from the default ``ManagedSettingsStore``.
    private func removeShields() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        store.shield.webDomainCategories = nil
    }
}
