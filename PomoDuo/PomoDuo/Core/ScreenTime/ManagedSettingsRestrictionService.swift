import FamilyControls
import ManagedSettings

/// Real restriction service implementation backed by Managed Settings shields.
@MainActor
final class ManagedSettingsRestrictionService: RestrictionService {
    private let screenTimeManager: ScreenTimeManager
    private let store: ManagedSettingsStore

    init(
        screenTimeManager: ScreenTimeManager,
        store: ManagedSettingsStore
    ) {
        self.screenTimeManager = screenTimeManager
        self.store = store
    }

    var isAuthorized: Bool {
        get async {
            screenTimeManager.isAuthorized
        }
    }

    /// Applies shields using the shared ``ShieldPolicyMapper`` so the main
    /// app and ``DeviceActivityMonitorExtension`` always compute and write
    /// the same policy for a given selection.
    ///
    /// ``FamilyActivitySelection`` is inclusive: every token it carries is
    /// something the user picked to block. The mapper writes category
    /// shields via ``ShieldSettings/ActivityCategoryPolicy/specific(_:)``
    /// for any selected categories, and writes the individual-applications
    /// and web-domains channels for any tokens picked outside of (or in
    /// addition to) the selected categories.
    func applyRestrictions() async throws {
        let decision = ShieldPolicyMapper.decide(
            for: screenTimeManager.activitySelection
        )

        ShieldPolicyMapper.apply(decision, to: store)
    }

    func removeRestrictions() async throws {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        store.shield.webDomainCategories = nil
    }
}
