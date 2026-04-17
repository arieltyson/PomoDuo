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
    /// ``FamilyActivitySelection`` is inclusive (every token it carries is
    /// something the user picked to block); the mapper additionally
    /// honors any ``ScreenTimeManager/categoryExceptions`` derived at
    /// commit time, threading them through
    /// ``ShieldSettings/ActivityCategoryPolicy/specific(_:except:)`` so a
    /// "shield this category, except this app" intent survives even
    /// though `FamilyActivitySelection` itself can't encode it.
    func applyRestrictions() async throws {
        let decision = ShieldPolicyMapper.decide(
            for: screenTimeManager.activitySelection,
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
