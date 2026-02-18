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
    }

    private func persistSelection() {
        guard let data = try? JSONEncoder().encode(activitySelection) else {
            return
        }
        UserDefaults.standard.set(data, forKey: Self.selectionDefaultsKey)
    }

    private func restoreSelection() {
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
