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

    /// The user's current picker selection.
    ///
    /// Constructed with `includeEntireCategory: true` so that picking
    /// "All Apps & Categories" and then deselecting specific apps records
    /// those deselections as exceptions in ``FamilyActivitySelection/applicationTokens``.
    /// ``ShieldPolicyMapper`` depends on that semantic to emit the correct
    /// `.all(except:)` policy — without it, deselecting a single app would
    /// drop an entire category from `categoryTokens` and silently unblock
    /// every uncategorized app plus every app in that category the picker
    /// hadn't enumerated.
    ///
    /// - Note: Legacy payloads saved before the ``ShieldPolicyMapper`` fix
    ///   carry `includeEntireCategory: false`. ``canonicalizeRestoredSelection(_:)``
    ///   normalizes every restored value back to `true` so the picker's
    ///   next edit uses exception-aware semantics, without needing any
    ///   migration step on the user's side.
    var activitySelection = FamilyActivitySelection(includeEntireCategory: true) {
        didSet {
            persistSelection()
        }
    }

    var isAuthorized: Bool {
        if authorizationStatus == .approved { return true }
        if #available(iOS 26.4, *),
            authorizationStatus == .approvedWithDataAccess
        {
            return true
        }
        return false
    }

    var hasSelectedApps: Bool {
        !activitySelection.applicationTokens.isEmpty
            || !activitySelection.categoryTokens.isEmpty
            || !activitySelection.webDomainTokens.isEmpty
    }

    private let store: ManagedSettingsStore
    private let persistenceDefaults: UserDefaults

    private static let selectionDefaultsKey = "com.pomoduo.screentime.selection"

    init(
        store: ManagedSettingsStore,
        persistenceDefaults: UserDefaults = .standard
    ) {
        self.store = store
        self.persistenceDefaults = persistenceDefaults
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
            if Self.shouldPresentAuthorizationAlert(for: error) {
                authorizationError = Self.userFacingMessage(for: error)
            }
        }

        refreshAuthorizationStatus()
        isRequestingAuthorization = false
    }

    func clearAuthorizationError() {
        authorizationError = nil
    }

    func clearSelection() {
        activitySelection = FamilyActivitySelection(includeEntireCategory: true)
        persistenceDefaults.removeObject(forKey: Self.selectionDefaultsKey)
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        store.shield.webDomainCategories = nil

        // Clear App Group so extensions stay in sync.
        ShieldSessionContext.writeSelection(
            FamilyActivitySelection(includeEntireCategory: true)
        )
    }

    private func persistSelection() {
        guard let data = try? JSONEncoder().encode(activitySelection) else {
            return
        }

        // Standard defaults for fast main-app reads.
        persistenceDefaults.set(data, forKey: Self.selectionDefaultsKey)

        // App Group so the DeviceActivity Monitor extension can read the
        // selection and reapply shields if the app is force-quit.
        ShieldSessionContext.writeSelection(activitySelection)
    }

    private func restoreSelection() {
        // Try App Group first (canonical for extensions), fall back to
        // standard defaults (legacy data from before extensions existed).
        if let shared = ShieldSessionContext.readSelection(),
            !shared.applicationTokens.isEmpty || !shared.categoryTokens.isEmpty
                || !shared.webDomainTokens.isEmpty
        {
            activitySelection = Self.canonicalizeRestoredSelection(shared)
            return
        }

        guard
            let data = persistenceDefaults.data(
                forKey: Self.selectionDefaultsKey
            ),
            let selection = try? JSONDecoder().decode(
                FamilyActivitySelection.self,
                from: data
            )
        else {
            return
        }

        let canonical = Self.canonicalizeRestoredSelection(selection)
        activitySelection = canonical

        // Migrate legacy data to App Group for extension access. Writing the
        // canonical form here (rather than the raw legacy `selection`) means
        // subsequent reads — including by the DeviceActivity Monitor
        // extension — land on the exception-aware flag, not the downgraded
        // one that the legacy payload was saved with.
        ShieldSessionContext.writeSelection(canonical)
    }

    /// Rebuilds a decoded ``FamilyActivitySelection`` so it always carries
    /// `includeEntireCategory: true`.
    ///
    /// Legacy payloads — saved before the ``ShieldPolicyMapper`` fix —
    /// carry `includeEntireCategory: false`. `FamilyActivityPicker` reads
    /// the flag off the bound selection, so without this canonicalization
    /// step an upgraded user who had a saved "All Apps & Categories +
    /// exceptions" selection would silently lose the exception-aware
    /// semantics the next time they opened the picker.
    ///
    /// Fresh payloads saved after the fix already carry `true` — Apple's
    /// `Codable` conformance preserves the flag — so this helper is a
    /// no-op for them. It is always safe to call.
    ///
    /// - Note: `internal` rather than `private` so regression tests can
    ///   cover the behavior directly. `@testable import` is the only
    ///   caller outside this type.
    static func canonicalizeRestoredSelection(
        _ decoded: FamilyActivitySelection
    ) -> FamilyActivitySelection {
        guard !decoded.includeEntireCategory else {
            return decoded
        }

        var canonical = FamilyActivitySelection(includeEntireCategory: true)
        canonical.applicationTokens = decoded.applicationTokens
        canonical.categoryTokens = decoded.categoryTokens
        canonical.webDomainTokens = decoded.webDomainTokens
        return canonical
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
                "Could not enable app blocking on this device right now. Please try again."
        }

        return "Could not enable app blocking: \(error.localizedDescription)"
    }

    private static func shouldPresentAuthorizationAlert(for error: Error) -> Bool {
        let loweredDescription = error.localizedDescription.localizedLowercase
        return loweredDescription.localizedStandardContains("denied") == false
    }
}
