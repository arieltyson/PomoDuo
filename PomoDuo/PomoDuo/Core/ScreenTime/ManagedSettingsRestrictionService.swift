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
    /// the same picker-selection policy.
    func applyRestrictions() async throws {
        let decision = ShieldPolicyMapper.decide(
            applicationTokens:
                screenTimeManager.activitySelection.applicationTokens,
            categoryTokens: screenTimeManager.shieldedCategoryTokens,
            webDomainTokens:
                screenTimeManager.activitySelection.webDomainTokens,
            categoryExceptions: screenTimeManager.categoryExceptions,
            webDomainCategoryExceptions:
                screenTimeManager.webDomainCategoryExceptions
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
