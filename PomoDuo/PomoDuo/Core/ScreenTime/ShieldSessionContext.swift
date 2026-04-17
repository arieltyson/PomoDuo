import FamilyControls
import Foundation

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

    /// Clears all session context when the session ends.
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
}
