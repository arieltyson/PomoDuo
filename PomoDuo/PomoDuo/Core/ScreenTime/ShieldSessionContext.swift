import FamilyControls
import Foundation
import ManagedSettings

/// Shared read/write interface for session context stored in the App Group.
///
/// The main app writes session metadata here; the Shield Configuration and
/// DeviceActivity Monitor extensions read it to display custom shields and
/// enforce or remove restrictions independently of the app process.
///
/// - Important: This file must have target membership in the main app,
///   `PomoDuoShieldExtension`, and `PomoDuoMonitorExtension`.
enum ShieldSessionContext {

    /// The App Group identifier shared across all three targets.
    static let appGroupID = "group.com.arieljtyson.pomoduo"

    /// Raw identifier for the DeviceActivity schedule. Shared between
    /// ``FocusActivityScheduler`` (main app) and the Monitor extension.
    static let focusActivityID = "com.pomoduo.focus"

    // MARK: - Keys

    private enum Keys {
        static let isSessionActive = "shield.session.isActive"
        static let partnerName = "shield.session.partnerName"
        static let sessionPhase = "shield.session.phase"
        static let targetEndDate = "shield.session.targetEndDate"
        static let activitySelection = "shield.session.activitySelection"
        static let shieldedCategoryTokens =
            "shield.session.shieldedCategoryTokens"
        static let categoryExceptions = "shield.session.categoryExceptions"
        static let webDomainCategoryExceptions =
            "shield.session.webDomainCategoryExceptions"
    }

    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    // MARK: - Write (Main App)

    /// Writes the current session state so extensions can read it.
    static func writeSession(
        partnerName: String?,
        phase: String,
        targetEndDate: Date
    ) {
        guard let defaults = sharedDefaults else { return }
        defaults.set(true, forKey: Keys.isSessionActive)
        defaults.set(partnerName, forKey: Keys.partnerName)
        defaults.set(phase, forKey: Keys.sessionPhase)
        defaults.set(
            targetEndDate.timeIntervalSince1970,
            forKey: Keys.targetEndDate
        )
    }

    /// Persists the user's app selection so extensions can reapply shields.
    static func writeSelection(_ selection: FamilyActivitySelection) {
        guard let defaults = sharedDefaults,
            let data = try? JSONEncoder().encode(selection)
        else { return }
        defaults.set(data, forKey: Keys.activitySelection)
    }

    /// Persists effective category shield tokens for the monitor extension.
    static func writeShieldedCategoryTokens(
        _ tokens: Set<ActivityCategoryToken>
    ) {
        guard let defaults = sharedDefaults else { return }
        guard !tokens.isEmpty else {
            defaults.removeObject(forKey: Keys.shieldedCategoryTokens)
            return
        }
        guard let data = try? JSONEncoder().encode(tokens) else { return }
        defaults.set(data, forKey: Keys.shieldedCategoryTokens)
    }

    /// Persists category exception tokens so the monitor extension can
    /// reapply the same shield policy as the main app.
    static func writeCategoryExceptions(_ exceptions: Set<ApplicationToken>) {
        guard let defaults = sharedDefaults else { return }
        guard !exceptions.isEmpty else {
            defaults.removeObject(forKey: Keys.categoryExceptions)
            return
        }
        guard let data = try? JSONEncoder().encode(exceptions) else { return }
        defaults.set(data, forKey: Keys.categoryExceptions)
    }

    /// Persists web-domain category exception tokens for monitor reapplication.
    static func writeWebDomainCategoryExceptions(
        _ exceptions: Set<WebDomainToken>
    ) {
        guard let defaults = sharedDefaults else { return }
        guard !exceptions.isEmpty else {
            defaults.removeObject(
                forKey: Keys.webDomainCategoryExceptions
            )
            return
        }
        guard let data = try? JSONEncoder().encode(exceptions) else { return }
        defaults.set(data, forKey: Keys.webDomainCategoryExceptions)
    }

    /// Clears all per-session context when the session ends.
    ///
    /// Note: this clears *session lifecycle* keys, not the user's
    /// stored selection. That outlives any individual session and is managed
    /// by ``ScreenTimeManager``'s `clearSelection()` path.
    static func clearSession() {
        guard let defaults = sharedDefaults else { return }
        defaults.set(false, forKey: Keys.isSessionActive)
        defaults.removeObject(forKey: Keys.partnerName)
        defaults.removeObject(forKey: Keys.sessionPhase)
        defaults.removeObject(forKey: Keys.targetEndDate)
    }

    /// Writes the partner's display name independently of session state.
    ///
    /// Called from the view layer which has access to the ``PartnerProfile``
    /// but not from ``SessionManager`` which only knows user IDs.
    static func writePartnerName(_ name: String) {
        sharedDefaults?.set(name, forKey: Keys.partnerName)
    }

    // MARK: - Read (Extensions)

    /// Whether a focus or break session is currently active.
    static var isSessionActive: Bool {
        sharedDefaults?.bool(forKey: Keys.isSessionActive) ?? false
    }

    /// The partner's display name, if available.
    static var partnerName: String? {
        sharedDefaults?.string(forKey: Keys.partnerName)
    }

    /// The current session phase label (e.g. "Focus", "Short Break").
    static var sessionPhase: String? {
        sharedDefaults?.string(forKey: Keys.sessionPhase)
    }

    /// The absolute date when the current period ends.
    static var targetEndDate: Date? {
        guard let defaults = sharedDefaults else { return nil }
        let interval = defaults.double(forKey: Keys.targetEndDate)
        guard interval > 0 else { return nil }
        return Date(timeIntervalSince1970: interval)
    }

    /// The user's app selection for shield enforcement.
    static func readSelection() -> FamilyActivitySelection? {
        guard let defaults = sharedDefaults,
            let data = defaults.data(forKey: Keys.activitySelection)
        else { return nil }
        return try? JSONDecoder().decode(
            FamilyActivitySelection.self,
            from: data
        )
    }

    /// Reads effective category shield tokens for monitor reapplication.
    static func readShieldedCategoryTokens()
        -> Set<ActivityCategoryToken>?
    {
        guard let defaults = sharedDefaults,
            let data = defaults.data(forKey: Keys.shieldedCategoryTokens)
        else { return nil }
        return try? JSONDecoder().decode(
            Set<ActivityCategoryToken>.self,
            from: data
        )
    }

    /// Reads derived app exceptions for category shield reapplication.
    static func readCategoryExceptions() -> Set<ApplicationToken>? {
        guard let defaults = sharedDefaults,
            let data = defaults.data(forKey: Keys.categoryExceptions)
        else { return nil }
        return try? JSONDecoder().decode(
            Set<ApplicationToken>.self,
            from: data
        )
    }

    /// Reads derived web-domain exceptions for category shield reapplication.
    static func readWebDomainCategoryExceptions() -> Set<WebDomainToken>? {
        guard let defaults = sharedDefaults,
            let data = defaults.data(
                forKey: Keys.webDomainCategoryExceptions
            )
        else { return nil }
        return try? JSONDecoder().decode(
            Set<WebDomainToken>.self,
            from: data
        )
    }

    // MARK: - Session-End Discrimination

    /// Whether the shared context still points to a session whose
    /// target end date is in the future as of `now`.
    ///
    /// The `DeviceActivityMonitor` extension uses this to distinguish a
    /// mid-session reschedule from a true session end. iOS fires
    /// `intervalDidEnd` *also* when the main app calls
    /// `DeviceActivityCenter.stopMonitoring(_:)` to replace the prior
    /// registration (which happens on every focus-session apply and
    /// reconcile, because ``FocusActivityScheduler/scheduleMonitoring(until:)``
    /// stops-then-starts). Without this check, the Monitor would tear
    /// down shields + shared context on every reschedule.
    ///
    /// `targetEndDate` is the truthiest signal available from inside
    /// the extension sandbox: if it's still in the future, the session
    /// is still expected to be running and this `intervalDidEnd` is a
    /// reschedule, not a genuine end.
    static func hasUnexpiredTargetEnd(asOf now: Date = .now) -> Bool {
        guard let targetEndDate else { return false }
        return targetEndDate > now
    }
}
