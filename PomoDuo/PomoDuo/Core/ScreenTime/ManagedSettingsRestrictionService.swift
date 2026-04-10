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
        store.shield.webDomains =
            webDomainTokens.isEmpty ? nil : webDomainTokens

        // "All Apps & Categories" from the picker populates categoryTokens
        // with every ActivityCategory. Using `.specific()` only covers apps
        // Apple has explicitly categorized — uncategorized or edge-case apps
        // slip through. `.all(except: [])` tells ManagedSettings to shield
        // everything regardless of category assignment.
        let allSelected = categoryTokens.count
            >= ShieldSessionContext.allCategoriesThreshold

        if categoryTokens.isEmpty {
            store.shield.applicationCategories = nil
            store.shield.webDomainCategories = nil
        } else if allSelected {
            store.shield.applicationCategories = .all(except: [])
            store.shield.webDomainCategories = .all(except: [])
        } else {
            store.shield.applicationCategories = .specific(categoryTokens)
            store.shield.webDomainCategories = .specific(categoryTokens)
        }
    }

    func removeRestrictions() async throws {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        store.shield.webDomainCategories = nil
    }
}
