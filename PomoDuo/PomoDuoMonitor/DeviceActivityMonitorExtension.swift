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
    private let activityCenter = DeviceActivityCenter()

    // MARK: - Interval Callbacks

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)

        guard activity.rawValue == ShieldSessionContext.focusActivityID else {
            return
        }

        // Record invocation telemetry *before* touching shields so the main
        // app can distinguish "extension never ran" from "extension ran but
        // shield apply failed" after the fact. Capture the shared-context
        // state the extension saw at this moment so the diagnostics view
        // can tell whether the context was healthy at callback time.
        recordInvocation(.monitorIntervalDidStart, for: activity)

        applyShields()
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)

        guard activity.rawValue == ShieldSessionContext.focusActivityID else {
            return
        }

        recordInvocation(.monitorIntervalDidEnd, for: activity)

        removeShields()
        ShieldSessionContext.clearSession()
    }

    // MARK: - Telemetry

    /// Captures the shared-context state the monitor extension observed
    /// at callback time. Writes only if the fired activity matches the
    /// focus activity name (the outer guards already ensure this).
    ///
    /// The DeviceActivity monitor sandbox allows both App Group
    /// `UserDefaults` writes and `DeviceActivityCenter` queries, so we
    /// additionally capture whether the focus activity is still
    /// registered from the extension's perspective — useful when
    /// diagnosing "the activity was removed before `intervalDidEnd`".
    private func recordInvocation(
        _ event: ShieldExtensionTelemetry.Event,
        for activity: DeviceActivityName
    ) {
        let registered = activityCenter.activities.contains(activity)
        ShieldExtensionTelemetry.record(
            event,
            isSessionActive: ShieldSessionContext.isSessionActive,
            phase: ShieldSessionContext.sessionPhase,
            targetEndDate: ShieldSessionContext.targetEndDate,
            focusActivityRegistered: registered
        )
    }

    // MARK: - Shield Management

    /// Reads the user's app selection from the shared App Group and applies
    /// shields via the same ``ShieldPolicyMapper`` the main app uses.
    ///
    /// Sharing the mapper guarantees the extension's re-application after a
    /// force-quit produces byte-identical shield writes — the inclusive
    /// mapping is a straight read of the selection, so this extension and
    /// the main app cannot disagree on what to shield.
    private func applyShields() {
        guard let selection = ShieldSessionContext.readSelection() else {
            return
        }

        let decision = ShieldPolicyMapper.decide(for: selection)

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
