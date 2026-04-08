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

    func applyRestrictions() async throws {
        let selection = screenTimeManager.activitySelection

        let appTokens = selection.applicationTokens
        let categoryTokens = selection.categoryTokens
        let webDomainTokens = selection.webDomainTokens

        // When the selection is empty, clear all shields so that stale
        // restrictions are never left behind (e.g. emergency mid-session unblock).
        store.shield.applications = appTokens.isEmpty ? nil : appTokens
        store.shield.applicationCategories =
            categoryTokens.isEmpty ? nil : .specific(categoryTokens)
        store.shield.webDomains =
            webDomainTokens.isEmpty ? nil : webDomainTokens
        store.shield.webDomainCategories =
            categoryTokens.isEmpty ? nil : .specific(categoryTokens)
    }

    func removeRestrictions() async throws {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        store.shield.webDomainCategories = nil
    }
}
