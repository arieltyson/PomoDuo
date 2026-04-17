import DeviceActivity
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

    /// Latest classification of the Screen Time pipeline's runtime health.
    ///
    /// Refreshed by ``RestrictionCoordinator`` after each apply / lift /
    /// reconcile, by `PomoDuoApp` on scene activation, and explicitly via
    /// ``refreshRuntimeHealth(focusIsActive:)``. Drives the active-session
    /// chip copy in ``TimerView`` and ``ActivePairedSessionView`` so the
    /// UI reflects what the app honestly knows rather than the stronger
    /// "Apps Blocked" claim the previous code made on bare `isRestricting`.
    private(set) var runtimeHealth: ScreenTimeRuntimeHealth = .unavailable(
        reason: .selectionEmpty
    )

    /// The user's current picker selection.
    ///
    /// Constructed with `includeEntireCategory: true` so the picker
    /// enumerates applications and web domains from any selected category
    /// into ``FamilyActivitySelection/applicationTokens`` and
    /// ``FamilyActivitySelection/webDomainTokens``. Apple's docs describe
    /// `includeEntireCategory` as "whether the selection should include
    /// applications and web domains from the selected categories" — this
    /// gives ``ShieldPolicyMapper`` a complete inclusive token set to
    /// shield, covering every app and domain the user picked directly
    /// *and* every app/domain that belongs to a picked category.
    ///
    /// - Note: Legacy payloads saved by earlier builds carry
    ///   `includeEntireCategory: false`. ``canonicalizeRestoredSelection(_:)``
    ///   normalizes every restored value back to `true` so the picker's
    ///   next edit includes the full expansion of any chosen category,
    ///   without needing any migration step on the user's side.
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
    private let activityCenter = DeviceActivityCenter()

    private static let selectionDefaultsKey = "com.pomoduo.screentime.selection"
    private static let focusActivityName = DeviceActivityName(
        rawValue: ShieldSessionContext.focusActivityID
    )

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

    // MARK: - Runtime Health

    /// Recomputes ``runtimeHealth`` from a fresh diagnostics snapshot.
    ///
    /// `focusIsActive` is the caller's understanding of whether a focus
    /// session is currently expected to be running — the coordinator
    /// passes its own `isRestricting`, the app shell passes whatever it
    /// can read off the coordinator on scene activation. Outside an active
    /// focus session, the runtime channels are *expected* to be empty, so
    /// passing `false` keeps the classifier from incorrectly reporting
    /// degradation.
    func refreshRuntimeHealth(focusIsActive: Bool) {
        runtimeHealth = ScreenTimeRuntimeHealth.evaluate(
            snapshot: diagnosticsSnapshot(),
            focusIsActive: focusIsActive
        )
    }

    // MARK: - Diagnostics & Recovery

    /// Computes a snapshot of every Screen Time piece the app currently
    /// configures or knows about.
    ///
    /// Used by ``AppBlockingDiagnosticsView`` to show on-device truth and
    /// by tests to assert reset/canonicalization behavior. The snapshot is
    /// deliberately scoped to "what the app set / what the system has
    /// registered" — Apple does not expose whether iOS is currently
    /// shielding apps, so this snapshot never claims that.
    func diagnosticsSnapshot() -> ScreenTimeDiagnostics {
        let selection = activitySelection
        let policyShape = ShieldPolicyMapper.decideShape(
            applicationTokenCount: selection.applicationTokens.count,
            categoryTokenCount: selection.categoryTokens.count,
            webDomainTokenCount: selection.webDomainTokens.count
        )

        let registered = activityCenter.activities.contains(
            Self.focusActivityName
        )
        let scheduleEnd = activityCenter.schedule(
            for: Self.focusActivityName
        )
        .flatMap { schedule in
            Calendar.current.date(from: schedule.intervalEnd)
        }

        return ScreenTimeDiagnostics(
            authorization: ScreenTimeDiagnostics.Authorization(
                status: authorizationStatus,
                isUsable: isAuthorized
            ),
            selection: ScreenTimeDiagnostics.Selection(
                applicationCount: selection.applicationTokens.count,
                categoryCount: selection.categoryTokens.count,
                webDomainCount: selection.webDomainTokens.count,
                isCanonical: selection.includeEntireCategory
            ),
            policy: policyShape,
            shieldChannels: ScreenTimeDiagnostics.ShieldChannels(
                applicationsConfigured: store.shield.applications != nil,
                applicationsCount: store.shield.applications?.count ?? 0,
                applicationCategoriesConfigured: store.shield
                    .applicationCategories != nil,
                webDomainsConfigured: store.shield.webDomains != nil,
                webDomainsCount: store.shield.webDomains?.count ?? 0,
                webDomainCategoriesConfigured: store.shield
                    .webDomainCategories != nil
            ),
            monitoring: ScreenTimeDiagnostics.Monitoring(
                focusActivityRegistered: registered,
                focusScheduleEnd: scheduleEnd
            ),
            sessionContext: ScreenTimeDiagnostics.SessionContext(
                isActive: ShieldSessionContext.isSessionActive,
                phase: ShieldSessionContext.sessionPhase,
                targetEndDate: ShieldSessionContext.targetEndDate
            ),
            capturedAt: .now
        )
    }

    /// Tears down every piece of Screen Time state PomoDuo controls.
    ///
    /// Used by the on-device "Reset App Blocking" recovery path so the user
    /// can recover from a stale state — a crashed session that left a
    /// `DeviceActivity` registration alive, an inconsistent App Group
    /// payload, or any combination — without resorting to delete/reinstall.
    ///
    /// The teardown is intentionally direct (no enqueue, no listener
    /// dependency) so it works even when the in-app
    /// ``RestrictionCoordinator`` is unaware of the stale state.
    /// ``RestrictionCoordinator`` will still observe the resulting
    /// `activitySelection` change via the existing `onChange` wiring and
    /// flip its own `isRestricting` flag back to `false`.
    func resetAllScreenTimeState() {
        // 1. Stop any active focus monitoring schedule. The Monitor
        //    extension reads from the same `DeviceActivityCenter` and will
        //    stop receiving callbacks once the activity is unregistered.
        activityCenter.stopMonitoring([Self.focusActivityName])

        // 2. Clear shared App Group session context so the Shield and
        //    Monitor extensions don't see a stale "focus is active" flag.
        ShieldSessionContext.clearSession()

        // 3. Clear the existing selection. `clearSelection()` already
        //    handles the in-memory rebuild (canonical empty selection),
        //    standard-defaults removal, App Group selection rewrite, and
        //    `ManagedSettingsStore.shield` channel teardown.
        clearSelection()
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
