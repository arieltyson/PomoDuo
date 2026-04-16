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

    /// Applies shields using the shared ``ShieldPolicyMapper`` so the main app
    /// and ``DeviceActivityMonitorExtension`` always compute and write the
    /// same policy for a given selection.
    ///
    /// This deliberately threads ``FamilyActivitySelection/applicationTokens``
    /// through the *exception* parameter of
    /// ``ShieldSettings/ActivityCategoryPolicy`` when the user picked
    /// "All Apps & Categories" and then deselected some apps — the older
    /// count-threshold-only mapping dropped from `.all(except: [])` to
    /// `.specific(N-1 categories)` on the first deselection and silently
    /// unblocked every uncategorized app and every app in the dropped
    /// category that the picker hadn't enumerated.
    func applyRestrictions() async throws {
        let decision = ShieldPolicyMapper.decide(
            for: screenTimeManager.activitySelection,
            allCategoriesThreshold: ShieldSessionContext.allCategoriesThreshold
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
