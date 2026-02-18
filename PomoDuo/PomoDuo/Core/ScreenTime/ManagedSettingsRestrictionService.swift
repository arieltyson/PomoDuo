import FamilyControls
import ManagedSettings

/// Real restriction service implementation backed by Managed Settings shields.
@MainActor
final class ManagedSettingsRestrictionService: RestrictionService {
    private let screenTimeManager: ScreenTimeManager
    private let store: ManagedSettingsStore

    init(
        screenTimeManager: ScreenTimeManager,
        store: ManagedSettingsStore = ManagedSettingsStore()
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

        guard !appTokens.isEmpty || !categoryTokens.isEmpty else {
            return
        }

        store.shield.applications = appTokens.isEmpty ? nil : appTokens
        store.shield.applicationCategories =
            categoryTokens.isEmpty ? nil : .specific(categoryTokens)
    }

    func removeRestrictions() async throws {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
    }
}
