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

    /// Apps the user has opted out of within a currently-shielded
    /// category, derived at commit time by ``commitDraft(_:)`` and used
    /// by ``ShieldPolicyMapper`` to emit
    /// ``ShieldSettings/ActivityCategoryPolicy/specific(_:except:)``.
    ///
    /// ### Why this exists separately from `activitySelection`
    ///
    /// Apple's `FamilyActivitySelection` cannot encode "shield this
    /// category but exempt this one app" — the struct has no exceptions
    /// field. When the user deselects a single app from a category that
    /// was shielded with `includeEntireCategory: true`, the picker
    /// demotes the category (drops it from `categoryTokens`, leaves the
    /// remaining picker-enumerated apps in `applicationTokens`). The
    /// pure inclusive mapper would then lose the entire category shield
    /// — every app in the category that the picker did not enumerate
    /// would silently unblock. That's the user-reported "unblock one
    /// app, many other apps unblock too" failure mode.
    ///
    /// ``commitDraft(_:)`` recovers the user's intent by diffing the
    /// new draft against the previously-committed selection: if a
    /// category was lost and one or more apps were removed at the same
    /// time, the lost category is restored and the removed apps become
    /// `categoryExceptions`. Apple's `.specific(_:except:)` policy
    /// accepts up to 50 exception tokens; commitDraft enforces the cap
    /// and falls back to the literal draft (no preservation) if the
    /// derived exceptions would exceed it.
    private(set) var categoryExceptions: Set<ApplicationToken> = [] {
        didSet {
            persistCategoryExceptions()
        }
    }

    /// Apple's documented limit on tokens that fit in
    /// `ActivityCategoryPolicy.specific(_:except:)` /
    /// `.all(except:)`. Exposed as a constant so tests and the commit
    /// algorithm reference one source of truth.
    static let categoryExceptionsLimit = 50

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
    private static let categoryExceptionsDefaultsKey =
        "com.pomoduo.screentime.categoryExceptions"
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
        categoryExceptions = []
        persistenceDefaults.removeObject(forKey: Self.selectionDefaultsKey)
        persistenceDefaults.removeObject(
            forKey: Self.categoryExceptionsDefaultsKey
        )
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        store.shield.webDomainCategories = nil

        // Clear App Group so extensions stay in sync.
        ShieldSessionContext.writeSelection(
            FamilyActivitySelection(includeEntireCategory: true)
        )
        ShieldSessionContext.writeCategoryExceptions([])
    }

    // MARK: - Commit (Draft → Active Selection)

    /// Atomically replaces the live selection with `draft`, deriving any
    /// category-with-exception intent from the diff against the prior
    /// committed state.
    ///
    /// **Why this exists.** ``AppBlockingView`` binds the picker to a
    /// local draft (not directly to ``activitySelection``) so the user
    /// can edit without each picker tap re-applying restrictions
    /// mid-edit. ``commitDraft(_:)`` is the single, atomic write the
    /// view performs when the user confirms the edit. It guarantees
    /// `activitySelection` and ``categoryExceptions`` move together so
    /// the downstream `onChange` observer in `PomoDuoApp` fires once
    /// for one coherent state, not N times for N picker taps.
    ///
    /// **Why exceptions are derived here, not by the picker.** The
    /// picker observed on device demotes a category to "specific apps"
    /// when the user deselects one app from inside it: the category
    /// disappears from `categoryTokens` and the remaining
    /// picker-enumerated apps are left in `applicationTokens` minus the
    /// deselected one. Without recovery, the lost category drops the
    /// system-wide category shield and unblocks every app in the
    /// category that the picker did not enumerate — the exact
    /// "deselect one app, many others unblock" failure the user
    /// reported. The diff below restores the lost category and stores
    /// the removed apps as exceptions so ``ShieldPolicyMapper`` writes
    /// `ActivityCategoryPolicy.specific(_:except:)` — Apple's
    /// documented shape for "shield this category, except these apps".
    ///
    /// **Limits.** Apple's `.specific(_:except:)` accepts up to 50
    /// exception tokens. If the derived exceptions would exceed
    /// ``categoryExceptionsLimit``, this method falls back to the
    /// literal draft (no preservation). That's a graceful degradation:
    /// the user's individual deselects are still honored at the
    /// `applicationTokens` level, but the category shield is lost; the
    /// alternative (truncating the exception list) would silently
    /// re-shield arbitrary apps the user explicitly deselected, which
    /// is a worse outcome.
    func commitDraft(_ draft: FamilyActivitySelection) {
        let canonicalDraft = Self.canonicalizeRestoredSelection(draft)

        let previousSelection = activitySelection
        let previousExceptions = categoryExceptions

        let lostCategories = previousSelection.categoryTokens
            .subtracting(canonicalDraft.categoryTokens)
        let removedApps = previousSelection.applicationTokens
            .subtracting(canonicalDraft.applicationTokens)

        // Recompose the committed-categories universe. If the draft
        // already covers a category, keep it; if a previously-shielded
        // category disappeared from the draft *and* the user removed
        // at least one app at the same time, treat that as a partial
        // deselect and restore the category. This handles the picker's
        // "demote a category to specific apps when you deselect one
        // app" behavior (option b).
        let restoredCategories: Set<ActivityCategoryToken> =
            (!lostCategories.isEmpty && !removedApps.isEmpty)
            ? canonicalDraft.categoryTokens.union(lostCategories)
            : canonicalDraft.categoryTokens

        // Derive exceptions from *any* apps removed between prev and
        // draft while a category context remains to except them from.
        // This covers both:
        //  - Picker (a): categoryTokens stays, an app disappears from
        //    applicationTokens → removed app becomes an exception
        //    against the still-selected category.
        //  - Picker (b): category disappears, picker rewrites apps to
        //    the remaining set. The restoredCategories branch above
        //    re-adds the category; the removed app becomes an
        //    exception exactly as in (a).
        //
        // Prior exceptions carry forward (the user's earlier
        // deselects remain honored). Any token the user has now
        // re-selected (i.e. it's back in the draft's applicationTokens)
        // is removed from the exception set because the user's most
        // recent intent is "shield this again".
        let derivedExceptions: Set<ApplicationToken>
        if restoredCategories.isEmpty {
            // No category context at all — there's nothing to except
            // from, so ignore both prior exceptions and new removals.
            derivedExceptions = []
        } else {
            derivedExceptions = previousExceptions
                .union(removedApps)
                .subtracting(canonicalDraft.applicationTokens)
        }

        let cappedExceptions: Set<ApplicationToken>
        let finalCategories: Set<ActivityCategoryToken>
        if derivedExceptions.count > Self.categoryExceptionsLimit {
            // Fallback: too many exceptions to express via Apple's
            // 50-token cap. Drop the category restoration and let the
            // draft stand on its own — the user's deselects survive at
            // the applications-channel level even though the category
            // shield is lost.
            finalCategories = canonicalDraft.categoryTokens
            cappedExceptions = []
        } else {
            finalCategories = restoredCategories
            cappedExceptions = derivedExceptions
        }

        // Build the committed selection. We keep the draft's
        // applicationTokens as-is (these are the apps the user wants
        // shielded *in addition to* the categories), and we splice in
        // the restored categories. The set semantics prevent
        // duplication.
        var committed = FamilyActivitySelection(includeEntireCategory: true)
        committed.applicationTokens = canonicalDraft.applicationTokens
        committed.categoryTokens = finalCategories
        committed.webDomainTokens = canonicalDraft.webDomainTokens

        // Apply atomically: assign exceptions first so the `didSet` on
        // `activitySelection` (which fires the downstream `onChange` →
        // refresh in `PomoDuoApp`) sees the new exception set already
        // in place. Both assignments are persisted via their `didSet`s.
        categoryExceptions = cappedExceptions
        activitySelection = committed
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
            webDomainTokenCount: selection.webDomainTokens.count,
            categoryExceptionCount: categoryExceptions.count
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
                isCanonical: selection.includeEntireCategory,
                categoryExceptionCount: categoryExceptions.count
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
            extensionTelemetry: ShieldExtensionTelemetry.snapshot(),
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

        // 3. Clear extension-invocation telemetry so a fresh diagnosis
        //    run starts from zero. Without this, stale counts from a
        //    previous session would make "did the extensions run this
        //    time?" ambiguous.
        ShieldExtensionTelemetry.reset()

        // 4. Clear the existing selection. `clearSelection()` already
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

    private func persistCategoryExceptions() {
        if let data = try? JSONEncoder().encode(categoryExceptions) {
            persistenceDefaults.set(
                data,
                forKey: Self.categoryExceptionsDefaultsKey
            )
        }
        // App Group so the Monitor extension applies the same exception
        // set when it reapplies shields after a force-quit.
        ShieldSessionContext.writeCategoryExceptions(categoryExceptions)
    }

    private func restoreSelection() {
        // Try App Group first (canonical for extensions), fall back to
        // standard defaults (legacy data from before extensions existed).
        if let shared = ShieldSessionContext.readSelection(),
            !shared.applicationTokens.isEmpty || !shared.categoryTokens.isEmpty
                || !shared.webDomainTokens.isEmpty
        {
            activitySelection = Self.canonicalizeRestoredSelection(shared)
            categoryExceptions = restoreCategoryExceptions()
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
        categoryExceptions = restoreCategoryExceptions()

        // Migrate legacy data to App Group for extension access. Writing the
        // canonical form here (rather than the raw legacy `selection`) means
        // subsequent reads — including by the DeviceActivity Monitor
        // extension — land on the exception-aware flag, not the downgraded
        // one that the legacy payload was saved with.
        ShieldSessionContext.writeSelection(canonical)
    }

    /// Restores ``categoryExceptions`` from persistence, preferring the
    /// App Group payload (so the value matches whatever the Monitor
    /// extension last saw) and falling back to standard defaults for
    /// installs that predate the App Group exception key.
    private func restoreCategoryExceptions() -> Set<ApplicationToken> {
        if let shared = ShieldSessionContext.readCategoryExceptions() {
            return shared
        }
        guard
            let data = persistenceDefaults.data(
                forKey: Self.categoryExceptionsDefaultsKey
            ),
            let restored = try? JSONDecoder().decode(
                Set<ApplicationToken>.self,
                from: data
            )
        else {
            return []
        }
        return restored
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
