import FamilyControls
import Foundation
import ManagedSettings
import Observation

/// Coordinates Screen Time authorization and selected apps/categories to block.
@MainActor
@Observable
final class ScreenTimeManager {
    private(set) var authorizationStatus: AuthorizationStatus
    private(set) var authorizationError: String?
    private(set) var isRequestingAuthorization = false

    var activitySelection = FamilyActivitySelection() {
        didSet {
            persistSelection()
        }
    }

    var isAuthorized: Bool {
        authorizationStatus == .approved
    }

    var hasSelectedApps: Bool {
        !activitySelection.applicationTokens.isEmpty
            || !activitySelection.categoryTokens.isEmpty
    }

    private let store: ManagedSettingsStore

    private static let selectionDefaultsKey = "com.pomoduo.screentime.selection"

    init(store: ManagedSettingsStore = ManagedSettingsStore()) {
        self.store = store
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
        restoreSelection()
    }

    func refreshAuthorizationStatus() {
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
    }

    func requestAuthorization() async {
        isRequestingAuthorization = true
        authorizationError = nil

        do {
            try await AuthorizationCenter.shared.requestAuthorization(
                for: .individual
            )
        } catch {
            authorizationError = Self.userFacingMessage(for: error)
        }

        refreshAuthorizationStatus()
        isRequestingAuthorization = false
    }

    func clearAuthorizationError() {
        authorizationError = nil
    }

    func clearSelection() {
        activitySelection = FamilyActivitySelection()
        UserDefaults.standard.removeObject(forKey: Self.selectionDefaultsKey)
        store.shield.applications = nil
        store.shield.applicationCategories = nil

        // Clear App Group so extensions stay in sync.
        ShieldSessionContext.writeSelection(FamilyActivitySelection())
    }

    private func persistSelection() {
        guard let data = try? JSONEncoder().encode(activitySelection) else {
            return
        }

        // Standard defaults for fast main-app reads.
        UserDefaults.standard.set(data, forKey: Self.selectionDefaultsKey)

        // App Group so the DeviceActivity Monitor extension can read the
        // selection and reapply shields if the app is force-quit.
        ShieldSessionContext.writeSelection(activitySelection)
    }

    private func restoreSelection() {
        // Try App Group first (canonical for extensions), fall back to
        // standard defaults (legacy data from before extensions existed).
        if let shared = ShieldSessionContext.readSelection(),
            !shared.applicationTokens.isEmpty || !shared.categoryTokens.isEmpty
        {
            activitySelection = shared
            return
        }

        guard
            let data = UserDefaults.standard.data(
                forKey: Self.selectionDefaultsKey
            ),
            let selection = try? JSONDecoder().decode(
                FamilyActivitySelection.self,
                from: data
            )
        else {
            return
        }

        activitySelection = selection

        // Migrate legacy data to App Group for extension access.
        ShieldSessionContext.writeSelection(selection)
    }

    private static func userFacingMessage(for error: Error) -> String {
        let nsError = error as NSError
        let loweredDescription = error.localizedDescription.localizedLowercase

        if loweredDescription.localizedStandardContains("denied") {
            return "Screen Time authorization was denied."
        }

        if loweredDescription.localizedStandardContains("restricted") {
            return "Screen Time is restricted on this device."
        }

        if loweredDescription.localizedStandardContains("unavailable") {
            return "Screen Time is unavailable on this device."
        }

        if nsError.domain.localizedStandardContains("familycontrols") {
            return
                "Could not enable app blocking. Confirm the Family Controls capability is enabled for the app target."
        }

        return "Could not enable app blocking: \(error.localizedDescription)"
    }
}
