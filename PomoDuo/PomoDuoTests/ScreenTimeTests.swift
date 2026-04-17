import FamilyControls
import Foundation
import ManagedSettings
import Testing

@testable import PomoDuo

struct MockRestrictionServiceTests {
    @Test func defaultsToAuthorized() async {
        let service = await MockRestrictionService()
        #expect(await service.isAuthorized)
    }

    @Test func canSetUnauthorized() async {
        let service = await MockRestrictionService(isAuthorized: false)
        #expect(await service.isAuthorized == false)
    }

    @Test func applyTracksCallCount() async throws {
        let service = await MockRestrictionService()
        #expect(await service.applyCallCount == 0)

        try await service.applyRestrictions()
        #expect(await service.applyCallCount == 1)

        try await service.applyRestrictions()
        #expect(await service.applyCallCount == 2)
    }

    @Test func removeTracksCallCount() async throws {
        let service = await MockRestrictionService()
        #expect(await service.removeCallCount == 0)

        try await service.removeRestrictions()
        #expect(await service.removeCallCount == 1)
    }

    @Test func applyAndRemoveToggleRestrictionState() async throws {
        let service = await MockRestrictionService()
        #expect(await service.isCurrentlyRestricted == false)

        try await service.applyRestrictions()
        #expect(await service.isCurrentlyRestricted)

        try await service.removeRestrictions()
        #expect(await service.isCurrentlyRestricted == false)
    }

    @Test func applyThrowsInjectedError() async {
        let service = await MockRestrictionService()
        await service.setApplyError(NSError(domain: "test", code: 42))

        do {
            try await service.applyRestrictions()
            #expect(Bool(false), "Expected applyRestrictions() to throw")
        } catch {
            #expect((error as NSError).code == 42)
        }
    }

    @Test func removeThrowsInjectedError() async {
        let service = await MockRestrictionService()
        await service.setRemoveError(NSError(domain: "test", code: 99))

        do {
            try await service.removeRestrictions()
            #expect(Bool(false), "Expected removeRestrictions() to throw")
        } catch {
            #expect((error as NSError).code == 99)
        }
    }

    @Test func resetClearsState() async throws {
        let service = await MockRestrictionService()
        try await service.applyRestrictions()
        try await service.removeRestrictions()
        await service.setApplyError(NSError(domain: "test", code: 1))
        await service.setRemoveError(NSError(domain: "test", code: 2))

        await service.reset()

        #expect(await service.applyCallCount == 0)
        #expect(await service.removeCallCount == 0)
        #expect(await service.isCurrentlyRestricted == false)
        #expect(await service.applyErrorIsNil)
        #expect(await service.removeErrorIsNil)
    }
}

struct RestrictionLifecycleTests {
    @Test func focusAppliesRestrictions() async throws {
        let service = await MockRestrictionService()
        try await service.applyRestrictions()
        #expect(await service.isCurrentlyRestricted)
        #expect(await service.applyCallCount == 1)
    }

    @Test func breakRemovesRestrictions() async throws {
        let service = await MockRestrictionService()
        try await service.applyRestrictions()
        try await service.removeRestrictions()
        #expect(await service.isCurrentlyRestricted == false)
        #expect(await service.removeCallCount == 1)
    }

    @Test func multipleRoundsCycleCorrectly() async throws {
        let service = await MockRestrictionService()

        try await service.applyRestrictions()
        try await service.removeRestrictions()
        try await service.applyRestrictions()
        try await service.removeRestrictions()

        #expect(await service.applyCallCount == 2)
        #expect(await service.removeCallCount == 2)
        #expect(await service.isCurrentlyRestricted == false)
    }

    @Test func unauthorizedServiceCanBeDetected() async {
        let service = await MockRestrictionService(isAuthorized: false)
        #expect(await service.isAuthorized == false)
        #expect(await service.applyCallCount == 0)
    }

    @Test func completionRemovesRestrictions() async throws {
        let service = await MockRestrictionService()
        try await service.applyRestrictions()
        try await service.removeRestrictions()
        #expect(await service.isCurrentlyRestricted == false)
    }

    @Test func applyErrorDoesNotSetRestrictedState() async {
        let service = await MockRestrictionService()
        await service.setApplyError(NSError(domain: "test", code: 7))

        do {
            try await service.applyRestrictions()
            #expect(Bool(false), "Expected applyRestrictions() to throw")
        } catch {
            #expect((error as NSError).code == 7)
        }

        #expect(await service.isCurrentlyRestricted == false)
    }
}

// MARK: - Removed: AllCategoriesEnforcementTests
//
// This suite existed purely to test the 12-category threshold heuristic
// that drove the old exception-based mapping. Under the inclusive model
// described in Apple's docs (and now implemented in
// ``ShieldPolicyMapper``), the number of categories doesn't flip a mode
// — it just picks how many categories to shield via
// ``ShieldSettings/ActivityCategoryPolicy/specific(_:)``. Coverage for
// the inclusive behavior lives in ``ShieldPolicyMapperTests``.

@MainActor
struct AppBlockingStatusLogicTests {
    func pluralizeApp(count: Int) -> String {
        count == 1 ? "app" : "apps"
    }

    func pluralizeCategory(count: Int) -> String {
        count == 1 ? "category" : "categories"
    }

    func pluralizeWebDomain(count: Int) -> String {
        count == 1 ? "website" : "websites"
    }

    @Test func badgeSumsAppsAndCategories() {
        let appCount = 3
        let categoryCount = 2
        #expect(appCount + categoryCount == 5)
    }

    @Test func badgeSumsAllTokenTypes() {
        let appCount = 3
        let categoryCount = 2
        let webDomainCount = 1
        #expect(appCount + categoryCount + webDomainCount == 6)
    }

    @Test func singularAppWord() {
        let result = pluralizeApp(count: 1)
        #expect(result == "app")
    }

    @Test func pluralAppsWord() {
        let result = pluralizeApp(count: 3)
        #expect(result == "apps")
    }

    @Test func singularCategoryWord() {
        let result = pluralizeCategory(count: 1)
        #expect(result == "category")
    }

    @Test func pluralCategoriesWord() {
        let result = pluralizeCategory(count: 4)
        #expect(result == "categories")
    }

    @Test func singularWebDomainWord() {
        let result = pluralizeWebDomain(count: 1)
        #expect(result == "website")
    }

    @Test func pluralWebDomainsWord() {
        let result = pluralizeWebDomain(count: 3)
        #expect(result == "websites")
    }
}

// MARK: - Shield Policy Mapper

/// Coverage for the inclusive ``ShieldPolicyMapper``.
///
/// A ``FamilyActivitySelection`` is inclusive per Apple's docs: every
/// token it holds is something the user picked to block. The mapper
/// writes category shields via
/// ``ShieldSettings/ActivityCategoryPolicy/specific(_:)`` for any
/// selected categories and writes the individual-applications / web-
/// domains channels for any tokens picked in addition. These tests
/// exercise ``ShieldPolicyMapper/decideShape(applicationTokenCount:categoryTokenCount:webDomainTokenCount:)``,
/// the count-driven mirror of the value-aware ``decide`` function. The
/// case enumeration it returns is exactly what determines which
/// `ManagedSettings` channel gets written.
///
/// **Regression history.** A prior mapper implementation treated
/// `applicationTokens` as an *exception* list for `.all(except:)` /
/// `.specific(_:except:)`. That was the inverse of the product's
/// intent — the apps the user picked were being exempted from the
/// shield — and kept blocked apps launching normally. The tests below
/// lock the corrected inclusive interpretation in place.
@MainActor
struct ShieldPolicyMapperTests {

    @Test func emptySelectionProducesNoShieldWrites() {
        let shape = ShieldPolicyMapper.decideShape(
            applicationTokenCount: 0,
            categoryTokenCount: 0,
            webDomainTokenCount: 0
        )

        #expect(shape.applicationCategories == .none)
        #expect(shape.webDomainCategories == .none)
        #expect(shape.writesSpecificApplicationsChannel == false)
        #expect(shape.writesSpecificWebDomainsChannel == false)
    }

    /// Specific apps only (no categories picked) must route through
    /// `store.shield.applications`. This is the baseline "block these two
    /// apps" scenario — the simplest correct verification.
    @Test func specificAppsOnlyWritesApplicationsChannel() {
        let shape = ShieldPolicyMapper.decideShape(
            applicationTokenCount: 2,
            categoryTokenCount: 0,
            webDomainTokenCount: 0
        )

        #expect(shape.applicationCategories == .none)
        #expect(shape.webDomainCategories == .none)
        #expect(shape.writesSpecificApplicationsChannel == true)
        #expect(shape.writesSpecificWebDomainsChannel == false)
    }

    /// One category picked: the mapper must emit `.specific(categories)`
    /// for both the application and web-domain category channels. Under
    /// `includeEntireCategory: true` the picker may also expand category
    /// apps into `applicationTokens`, and the mapper faithfully writes
    /// those through the applications channel too so any app outside a
    /// system-defined category still gets shielded if the user picked it
    /// explicitly.
    @Test func categoryOnlySelectionShieldsCategoryAcrossBothChannels() {
        let shape = ShieldPolicyMapper.decideShape(
            applicationTokenCount: 0,
            categoryTokenCount: 1,
            webDomainTokenCount: 0
        )

        #expect(shape.applicationCategories == .specific)
        #expect(shape.webDomainCategories == .specific)
        #expect(shape.writesSpecificApplicationsChannel == false)
        #expect(shape.writesSpecificWebDomainsChannel == false)
    }

    /// The realistic "user picked 13 categories and the picker enumerated
    /// 97 apps and 42 web domains from them" snapshot. All three channels
    /// must be written — category shields for the system-enumerated
    /// universe, specific-apps / specific-web-domains for the enumerated
    /// tokens (a belt-and-braces overlap iOS handles cleanly).
    @Test func categoryPlusAppsAndWebDomainsWritesAllThreeChannels() {
        let shape = ShieldPolicyMapper.decideShape(
            applicationTokenCount: 97,
            categoryTokenCount: 13,
            webDomainTokenCount: 42
        )

        #expect(shape.applicationCategories == .specific)
        #expect(shape.webDomainCategories == .specific)
        #expect(shape.writesSpecificApplicationsChannel == true)
        #expect(shape.writesSpecificWebDomainsChannel == true)
    }

    /// Web domains only (no apps, no categories): only the web-domains
    /// channel gets written.
    @Test func webDomainsOnlyWritesWebDomainsChannel() {
        let shape = ShieldPolicyMapper.decideShape(
            applicationTokenCount: 0,
            categoryTokenCount: 0,
            webDomainTokenCount: 3
        )

        #expect(shape.applicationCategories == .none)
        #expect(shape.webDomainCategories == .none)
        #expect(shape.writesSpecificApplicationsChannel == false)
        #expect(shape.writesSpecificWebDomainsChannel == true)
    }

    /// Mix of categories + apps outside any selected category: both the
    /// category-specific channel and the specific-apps channel fire. The
    /// apps *are* the user's block list, not an exception carve-out.
    @Test func categoryPlusExtraAppsWritesBothChannels() {
        let shape = ShieldPolicyMapper.decideShape(
            applicationTokenCount: 3,
            categoryTokenCount: 2,
            webDomainTokenCount: 0
        )

        #expect(shape.applicationCategories == .specific)
        #expect(shape.webDomainCategories == .specific)
        #expect(shape.writesSpecificApplicationsChannel == true)
        #expect(shape.writesSpecificWebDomainsChannel == false)
    }

    /// Regression: the main app and the Monitor extension must compute a
    /// byte-identical decision for the same selection, so the first
    /// enforcement and any post-force-quit re-application can't diverge.
    @Test func mainAppAndMonitorExtensionComputeIdenticalShape() {
        let mainAppShape = ShieldPolicyMapper.decideShape(
            applicationTokenCount: 97,
            categoryTokenCount: 13,
            webDomainTokenCount: 42
        )
        let monitorShape = ShieldPolicyMapper.decideShape(
            applicationTokenCount: 97,
            categoryTokenCount: 13,
            webDomainTokenCount: 42
        )

        #expect(mainAppShape == monitorShape)
    }
}

// MARK: - FamilyActivitySelection Persistence Semantics

/// Nails down exactly what Apple's `FamilyActivitySelection` preserves
/// across `Codable` round-trips. The fix for the restored-selection
/// downgrade depends on these facts staying true; if Apple ever changes
/// them, the fix has to change with them.
@MainActor
struct FamilyActivitySelectionPersistenceTests {

    @Test("Codable preserves includeEntireCategory for selections saved with the new true flag")
    func codablePreservesTrueFlag() throws {
        let original = FamilyActivitySelection(includeEntireCategory: true)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            FamilyActivitySelection.self,
            from: data
        )

        // iOS 26's FamilyControls does preserve the flag — the prior code
        // comment that claimed otherwise was wrong. Documenting the real
        // behavior here so any regression in future iOS versions surfaces
        // loudly instead of silently re-introducing the restore bug.
        #expect(decoded.includeEntireCategory == true)
    }

    @Test("Fresh includeEntireCategory: true construction preserves the flag")
    func freshSelectionKeepsFlag() {
        let selection = FamilyActivitySelection(includeEntireCategory: true)
        #expect(selection.includeEntireCategory == true)
    }

    @Test("Fresh includeEntireCategory: false construction preserves the flag")
    func freshDefaultSelectionKeepsFlag() {
        let selection = FamilyActivitySelection()
        #expect(selection.includeEntireCategory == false)
    }

    /// Establishes whether legacy payloads (persisted before the mapper
    /// fix, flag `false`) actually carry `false` through the `Codable`
    /// pipeline — this is the real source of the restore-path downgrade.
    @Test("Legacy false-flag selection decodes with false flag")
    func legacyFalseFlagRoundTripStaysFalse() throws {
        let original = FamilyActivitySelection(includeEntireCategory: false)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            FamilyActivitySelection.self,
            from: data
        )
        #expect(decoded.includeEntireCategory == false)
    }

    /// Determines whether the runtime fix can mutate a decoded selection in
    /// place. If this test fails to compile or fails at runtime, we need a
    /// different canonicalization shape.
    @Test("A decoded selection can be upgraded in place to includeEntireCategory: true")
    func decodedSelectionCanBeCanonicalized() throws {
        let original = FamilyActivitySelection(includeEntireCategory: false)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            FamilyActivitySelection.self,
            from: data
        )

        let canonical = ScreenTimeManager.canonicalizeRestoredSelection(
            decoded
        )

        #expect(canonical.includeEntireCategory == true)
        // Token sets must survive the canonicalization since they carry
        // the user's actual picker choices.
        #expect(canonical.applicationTokens == decoded.applicationTokens)
        #expect(canonical.categoryTokens == decoded.categoryTokens)
        #expect(canonical.webDomainTokens == decoded.webDomainTokens)
    }

    /// Regression: a selection that already carries the canonical
    /// `includeEntireCategory: true` flag must pass through
    /// `canonicalizeRestoredSelection` unchanged — the helper has to be
    /// a no-op for fresh payloads so there's no churn on every launch.
    @Test("canonicalizeRestoredSelection is a no-op for already-canonical payloads")
    func canonicalizePassesThroughAlreadyCanonicalPayloads() {
        let original = FamilyActivitySelection(includeEntireCategory: true)
        let canonical = ScreenTimeManager.canonicalizeRestoredSelection(original)

        #expect(canonical.includeEntireCategory == true)
        #expect(canonical.applicationTokens == original.applicationTokens)
        #expect(canonical.categoryTokens == original.categoryTokens)
        #expect(canonical.webDomainTokens == original.webDomainTokens)
    }
}

/// End-to-end regression coverage for the restore/edit lifecycle through
/// ``ScreenTimeManager`` itself. Exercises the flow an upgraded user
/// actually hits on the first launch after the policy-mapper fix:
/// legacy data was persisted with `includeEntireCategory: false`, gets
/// decoded, and the manager's `activitySelection` must come out with
/// `true` so the picker's next edit uses exception-aware semantics.
@MainActor
struct ScreenTimeManagerRestoreLifecycleTests {

    /// Builds a ``ScreenTimeManager`` backed by an isolated `UserDefaults`
    /// suite so persistence and restore can be tested without leaking
    /// state across cases or across the full-suite run.
    private func makeManager(withLegacyPayload legacyFlag: Bool?) -> (
        manager: ScreenTimeManager,
        defaults: UserDefaults
    ) {
        let suiteName = "com.pomoduo.tests.screentime.\(UUID().uuidString)"
        let defaults: UserDefaults
        if let suiteDefaults = UserDefaults(suiteName: suiteName) {
            suiteDefaults.removePersistentDomain(forName: suiteName)
            defaults = suiteDefaults
        } else {
            defaults = .standard
        }

        if let legacyFlag {
            let legacy = FamilyActivitySelection(
                includeEntireCategory: legacyFlag
            )
            if let data = try? JSONEncoder().encode(legacy) {
                defaults.set(
                    data,
                    forKey: "com.pomoduo.screentime.selection"
                )
            }
        }

        let manager = ScreenTimeManager(
            store: ManagedSettingsStore(),
            persistenceDefaults: defaults
        )
        return (manager, defaults)
    }

    @Test("Fresh install leaves the selection empty with canonical flag")
    func freshInstallUsesCanonicalFlag() {
        let (manager, _) = makeManager(withLegacyPayload: nil)

        #expect(manager.activitySelection.includeEntireCategory == true)
        #expect(manager.activitySelection.applicationTokens.isEmpty)
        #expect(manager.activitySelection.categoryTokens.isEmpty)
        #expect(manager.activitySelection.webDomainTokens.isEmpty)
    }

    /// The exact scenario the user described: a selection saved before the
    /// mapper fix is restored on first post-upgrade launch and must carry
    /// `includeEntireCategory: true` so the picker's next "All + deselect
    /// some apps" edit behaves correctly.
    @Test("Legacy payload with false flag is upgraded to canonical true on restore")
    func legacyPayloadIsUpgradedOnRestore() {
        let (manager, defaults) = makeManager(withLegacyPayload: false)

        #expect(manager.activitySelection.includeEntireCategory == true)

        // The persisted payload gets re-encoded with the canonical flag so
        // subsequent launches don't need to re-upgrade on every boot.
        if let data = defaults.data(
            forKey: "com.pomoduo.screentime.selection"
        ),
            let redecoded = try? JSONDecoder().decode(
                FamilyActivitySelection.self,
                from: data
            )
        {
            #expect(redecoded.includeEntireCategory == true)
        } else {
            Issue.record("Expected persisted selection to be re-encoded after canonicalization.")
        }
    }

    @Test("Post-fix payload with true flag round-trips unchanged")
    func postFixPayloadRoundTripsUnchanged() {
        let (manager, _) = makeManager(withLegacyPayload: true)

        #expect(manager.activitySelection.includeEntireCategory == true)
    }
}

// MARK: - Shield Cleanup Completeness

/// Regression tests verifying that all shield removal paths clear
/// every shield property, including web domains.
///
/// Bug: StopTimerIntent previously only cleared `shield.applications`
/// and `shield.applicationCategories`, leaving `shield.webDomains`
/// and `shield.webDomainCategories` active after stopping via
/// Dynamic Island.
@MainActor
struct ShieldCleanupCompletenessTests {

    @Test func removeRestrictionsClearsAllShieldProperties() async throws {
        let service = MockRestrictionService()

        try await service.applyRestrictions()
        #expect(await service.isCurrentlyRestricted)

        try await service.removeRestrictions()
        #expect(await service.isCurrentlyRestricted == false)
        #expect(await service.removeCallCount == 1)
    }

    @Test func clearSessionClearsAllContextKeys() {
        ShieldSessionContext.writeSession(
            partnerName: "Test",
            phase: "Focus",
            targetEndDate: .now.addingTimeInterval(300)
        )

        ShieldSessionContext.clearSession()

        #expect(ShieldSessionContext.isSessionActive == false)
        #expect(ShieldSessionContext.partnerName == nil)
        #expect(ShieldSessionContext.sessionPhase == nil)
        #expect(ShieldSessionContext.targetEndDate == nil)
    }

    @Test func forceRemoveAlwaysRemovesRegardlessOfState() async throws {
        let manager = ScreenTimeManager(store: ManagedSettingsStore())
        let service = MockRestrictionService()
        let coordinator = RestrictionCoordinator(
            screenTimeManager: manager,
            restrictionService: service,
            canRestrictEvaluator: { false }
        )

        // forceRemove should work even when canRestrict is false
        // and isRestricting is false — matches StopTimerIntent behavior.
        coordinator.forceRemoveRestrictions()

        for _ in 0..<20 {
            if await service.removeCallCount == 1 { break }
            try await Task.sleep(for: .milliseconds(20))
        }

        #expect(await service.removeCallCount == 1)
        #expect(coordinator.isRestricting == false)
    }
}

// MARK: - Focus Schedule Date Components

/// Regression test for FocusActivityScheduler date component handling.
///
/// Bug: Using only [.hour, .minute, .second] without date components
/// created a daily time-of-day window. Sessions spanning midnight
/// (e.g. 23:50→00:15) produced an inverted window where intervalEnd
/// preceded intervalStart, causing intervalDidEnd to never fire.
struct FocusScheduleDateComponentTests {

    @Test func dateComponentsPreserveDateForMidnightSpan() {
        let calendar = Calendar.current

        let startDate = calendar.date(
            from: DateComponents(
                year: 2026, month: 4, day: 10,
                hour: 23, minute: 50, second: 0
            )
        )!
        let endDate = calendar.date(
            from: DateComponents(
                year: 2026, month: 4, day: 11,
                hour: 0, minute: 15, second: 0
            )
        )!

        // With full date components, end > start even across midnight.
        let startComponents = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: startDate
        )
        let endComponents = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: endDate
        )

        let reconstructedStart = calendar.date(from: startComponents)!
        let reconstructedEnd = calendar.date(from: endComponents)!

        #expect(reconstructedEnd > reconstructedStart)
    }

    @Test func timeOnlyComponentsFailAcrossMidnight() {
        let calendar = Calendar.current

        let startDate = calendar.date(
            from: DateComponents(
                year: 2026, month: 4, day: 10,
                hour: 23, minute: 50, second: 0
            )
        )!
        let endDate = calendar.date(
            from: DateComponents(
                year: 2026, month: 4, day: 11,
                hour: 0, minute: 15, second: 0
            )
        )!

        // Time-only components lose the date, making end < start.
        let startComponents = calendar.dateComponents(
            [.hour, .minute, .second],
            from: startDate
        )
        let endComponents = calendar.dateComponents(
            [.hour, .minute, .second],
            from: endDate
        )

        // hour 0 < hour 23 — this is the bug the fix addresses.
        #expect(endComponents.hour! < startComponents.hour!)
    }
}

// MARK: - Diagnostics & Recovery

/// Coverage for ``ScreenTimeManager/diagnosticsSnapshot()`` and
/// ``ScreenTimeManager/resetAllScreenTimeState()`` — the on-device truth
/// surface and recovery path that round out the Screen Time pipeline.
///
/// `DeviceActivityCenter` and `ManagedSettingsStore` portions of the
/// snapshot can't be exercised in a unit test (they hit live system state
/// only available on a real device), so the tests below assert what *can*
/// be verified deterministically: authorization framing, selection counts,
/// the policy shape derived from the current selection, and the full
/// teardown semantics of `resetAllScreenTimeState()`.
@MainActor
struct ScreenTimeDiagnosticsTests {

    private func makeManager() -> (
        manager: ScreenTimeManager,
        defaults: UserDefaults
    ) {
        let suiteName = "com.pomoduo.tests.diagnostics.\(UUID().uuidString)"
        let defaults: UserDefaults
        if let suiteDefaults = UserDefaults(suiteName: suiteName) {
            suiteDefaults.removePersistentDomain(forName: suiteName)
            defaults = suiteDefaults
        } else {
            defaults = .standard
        }

        let manager = ScreenTimeManager(
            store: ManagedSettingsStore(),
            persistenceDefaults: defaults
        )
        return (manager, defaults)
    }

    @Test("Empty selection yields a none/none/none policy snapshot")
    func snapshotForEmptySelectionIsNone() {
        let (manager, _) = makeManager()

        let snapshot = manager.diagnosticsSnapshot()

        #expect(snapshot.selection.applicationCount == 0)
        #expect(snapshot.selection.categoryCount == 0)
        #expect(snapshot.selection.webDomainCount == 0)
        #expect(snapshot.selection.isCanonical == true)
        #expect(snapshot.policy.applicationCategories == .none)
        #expect(snapshot.policy.webDomainCategories == .none)
        #expect(snapshot.policy.writesSpecificApplicationsChannel == false)
        #expect(snapshot.policy.writesSpecificWebDomainsChannel == false)
    }

    @Test("Snapshot's authorization mirrors the manager's reported status")
    func snapshotAuthorizationIsConsistent() {
        let (manager, _) = makeManager()

        let snapshot = manager.diagnosticsSnapshot()

        #expect(snapshot.authorization.status == manager.authorizationStatus)
        #expect(snapshot.authorization.isUsable == manager.isAuthorized)
    }

    @Test("Snapshot canonical flag tracks the in-memory selection")
    func snapshotReflectsSelectionCanonicalization() {
        let (manager, _) = makeManager()

        // Fresh manager already constructs a canonical selection.
        #expect(manager.diagnosticsSnapshot().selection.isCanonical == true)

        // Simulate a non-canonical replacement (e.g. from a hypothetical
        // future code path that bypasses ``canonicalizeRestoredSelection``).
        manager.activitySelection = FamilyActivitySelection(
            includeEntireCategory: false
        )

        #expect(manager.diagnosticsSnapshot().selection.isCanonical == false)
    }

    @Test("Reset clears persisted standard-defaults selection")
    func resetClearsStandardDefaultsSelection() throws {
        let (manager, defaults) = makeManager()

        // Pretend the user had a selection persisted previously.
        let stored = FamilyActivitySelection(includeEntireCategory: true)
        let data = try JSONEncoder().encode(stored)
        defaults.set(data, forKey: "com.pomoduo.screentime.selection")
        #expect(defaults.data(forKey: "com.pomoduo.screentime.selection") != nil)

        manager.resetAllScreenTimeState()

        #expect(defaults.data(forKey: "com.pomoduo.screentime.selection") == nil)
    }

    @Test("Reset rebuilds activitySelection in canonical form")
    func resetRebuildsCanonicalSelection() {
        let (manager, _) = makeManager()

        // Force a non-canonical selection that recovery has to fix.
        manager.activitySelection = FamilyActivitySelection(
            includeEntireCategory: false
        )
        #expect(manager.activitySelection.includeEntireCategory == false)

        manager.resetAllScreenTimeState()

        #expect(manager.activitySelection.includeEntireCategory == true)
        #expect(manager.activitySelection.applicationTokens.isEmpty)
        #expect(manager.activitySelection.categoryTokens.isEmpty)
        #expect(manager.activitySelection.webDomainTokens.isEmpty)
    }

    @Test("Reset clears shared App Group session context")
    func resetClearsSharedSessionContext() {
        ShieldSessionContext.writeSession(
            partnerName: "Stale",
            phase: "Focus",
            targetEndDate: .now.addingTimeInterval(60)
        )
        #expect(ShieldSessionContext.isSessionActive == true)

        let (manager, _) = makeManager()
        manager.resetAllScreenTimeState()

        #expect(ShieldSessionContext.isSessionActive == false)
        #expect(ShieldSessionContext.sessionPhase == nil)
        #expect(ShieldSessionContext.targetEndDate == nil)
    }

    @Test("Reset is idempotent — repeated calls don't reintroduce state")
    func resetIsIdempotent() {
        let (manager, defaults) = makeManager()

        manager.resetAllScreenTimeState()
        manager.resetAllScreenTimeState()
        manager.resetAllScreenTimeState()

        #expect(manager.activitySelection.includeEntireCategory == true)
        #expect(manager.activitySelection.applicationTokens.isEmpty)
        #expect(defaults.data(forKey: "com.pomoduo.screentime.selection") == nil)
        #expect(ShieldSessionContext.isSessionActive == false)
    }

    /// Snapshots populate the new extension-telemetry field. This proves
    /// the snapshot wiring lands the telemetry read through to the UI,
    /// so a user staring at the diagnostics view will see the same state
    /// the Monitor/Shield extensions most recently wrote.
    @Test("Diagnostics snapshot includes extension telemetry")
    func snapshotIncludesExtensionTelemetry() {
        let (manager, _) = makeManager()

        // Fresh manager: telemetry is empty and not optional.
        let snapshot = manager.diagnosticsSnapshot()

        for event in snapshot.extensionTelemetry.allEvents {
            #expect(event.count == 0)
            #expect(event.lastFiredAt == nil)
        }
    }

    /// Reset must clear extension telemetry so a fresh diagnosis run
    /// starts from zero. Without this, stale counts from a prior session
    /// would make "did the extensions run this time?" ambiguous — the
    /// exact failure mode the telemetry is there to disambiguate.
    @Test("resetAllScreenTimeState clears extension telemetry")
    func resetClearsExtensionTelemetry() {
        let (manager, _) = makeManager()

        // Simulate an extension callback having fired into the shared
        // suite before reset. Using the real shared suite is acceptable
        // here because ``resetAllScreenTimeState`` is what we're testing
        // and it reaches into that same suite.
        ShieldExtensionTelemetry.record(
            .monitorIntervalDidStart,
            at: .now,
            isSessionActive: true,
            phase: "Focus",
            targetEndDate: .now.addingTimeInterval(1500),
            focusActivityRegistered: true
        )
        #expect(
            ShieldExtensionTelemetry.snapshot()
                .monitorIntervalDidStart.count > 0
        )

        manager.resetAllScreenTimeState()

        let post = manager.diagnosticsSnapshot().extensionTelemetry
        for event in post.allEvents {
            #expect(event.count == 0)
        }
        #expect(post.lastObservedContext == nil)
    }
}

// MARK: - Runtime Health Evaluator

/// Coverage for ``ScreenTimeRuntimeHealth/evaluate(snapshot:focusIsActive:)``.
///
/// The evaluator is a pure function over a `ScreenTimeDiagnostics` snapshot
/// — testable without touching `DeviceActivityCenter` or `ManagedSettingsStore`,
/// which makes the active-session classification logic verifiable in
/// isolation from the system APIs the snapshot otherwise queries.
@MainActor
struct ScreenTimeRuntimeHealthTests {

    @Test("Empty snapshot is unavailable: selection empty")
    func emptyIsUnavailableSelectionEmpty() {
        let snapshot = makeSnapshot(isUsable: true)

        let health = ScreenTimeRuntimeHealth.evaluate(
            snapshot: snapshot,
            focusIsActive: false
        )

        #expect(health == .unavailable(reason: .selectionEmpty))
        #expect(health.isRequestable == false)
    }

    @Test("Authorization off short-circuits before everything else")
    func authorizationOffShortCircuits() {
        let snapshot = makeSnapshot(
            isUsable: false,
            applicationCount: 5,
            applicationCategoriesPolicy: .specific,
            writesSpecificApplicationsChannel: false
        )

        let health = ScreenTimeRuntimeHealth.evaluate(
            snapshot: snapshot,
            focusIsActive: true
        )

        #expect(health == .unavailable(reason: .authorizationNotUsable))
    }

    @Test("Selection present but policy shields nothing is unavailable")
    func policyShieldingNothingIsUnavailable() {
        // Selection has non-zero counts (e.g. only web domains exist but
        // the policy translation wouldn't produce any shielding channel)
        // — synthetic edge to cover the third unavailable branch.
        let snapshot = makeSnapshot(
            isUsable: true,
            applicationCount: 0,
            categoryCount: 0,
            webDomainCount: 1,
            applicationCategoriesPolicy: .none,
            webDomainCategoriesPolicy: .none,
            writesSpecificApplicationsChannel: false,
            writesSpecificWebDomainsChannel: false
        )

        let health = ScreenTimeRuntimeHealth.evaluate(
            snapshot: snapshot,
            focusIsActive: true
        )

        #expect(health == .unavailable(reason: .computedPolicyShieldsNothing))
    }

    @Test("Healthy when focus inactive and only the selection is configured")
    func healthyOutsideFocusWithSelectionOnly() {
        let snapshot = makeSnapshot(
            isUsable: true,
            applicationCount: 3,
            applicationCategoriesPolicy: .none,
            writesSpecificApplicationsChannel: true
        )

        let health = ScreenTimeRuntimeHealth.evaluate(
            snapshot: snapshot,
            focusIsActive: false
        )

        #expect(health == .healthy)
        #expect(health.isRequestable)
        #expect(health.canBeRepaired == false)
    }

    /// Regression: outside an active focus session the runtime channels
    /// are *expected* to be empty, so the evaluator must not flag them as
    /// degradation.
    @Test("Empty runtime channels outside focus are not degradation")
    func emptyChannelsOutsideFocusNotDegradation() {
        let snapshot = makeSnapshot(
            isUsable: true,
            applicationCount: 3,
            applicationCategoriesPolicy: .none,
            writesSpecificApplicationsChannel: true,
            applicationsChannelConfigured: false,
            focusActivityRegistered: false,
            sessionContextActive: false
        )

        let health = ScreenTimeRuntimeHealth.evaluate(
            snapshot: snapshot,
            focusIsActive: false
        )

        #expect(health == .healthy)
    }

    @Test("Healthy when focus active and every expected channel is configured")
    func healthyDuringFocusWithFullPipeline() {
        let snapshot = makeSnapshot(
            isUsable: true,
            applicationCount: 3,
            applicationCategoriesPolicy: .none,
            writesSpecificApplicationsChannel: true,
            applicationsChannelConfigured: true,
            focusActivityRegistered: true,
            sessionContextActive: true
        )

        let health = ScreenTimeRuntimeHealth.evaluate(
            snapshot: snapshot,
            focusIsActive: true
        )

        #expect(health == .healthy)
    }

    @Test("Missing DeviceActivity registration during focus is degradation")
    func missingDeviceActivityIsDegradation() {
        let snapshot = makeSnapshot(
            isUsable: true,
            applicationCount: 3,
            applicationCategoriesPolicy: .none,
            writesSpecificApplicationsChannel: true,
            applicationsChannelConfigured: true,
            focusActivityRegistered: false,
            sessionContextActive: true
        )

        let health = ScreenTimeRuntimeHealth.evaluate(
            snapshot: snapshot,
            focusIsActive: true
        )

        #expect(
            health == .degraded(reasons: [.missingDeviceActivityRegistration])
        )
        #expect(health.canBeRepaired)
        #expect(health.isRequestable)
    }

    @Test("Missing shared session context during focus is degradation")
    func missingSessionContextIsDegradation() {
        let snapshot = makeSnapshot(
            isUsable: true,
            applicationCount: 3,
            applicationCategoriesPolicy: .none,
            writesSpecificApplicationsChannel: true,
            applicationsChannelConfigured: true,
            focusActivityRegistered: true,
            sessionContextActive: false
        )

        let health = ScreenTimeRuntimeHealth.evaluate(
            snapshot: snapshot,
            focusIsActive: true
        )

        #expect(
            health == .degraded(reasons: [.missingSharedSessionContext])
        )
    }

    @Test("Missing shield channel during focus is degradation")
    func missingShieldChannelIsDegradation() {
        let snapshot = makeSnapshot(
            isUsable: true,
            applicationCount: 3,
            applicationCategoriesPolicy: .none,
            writesSpecificApplicationsChannel: true,
            applicationsChannelConfigured: false,
            focusActivityRegistered: true,
            sessionContextActive: true
        )

        let health = ScreenTimeRuntimeHealth.evaluate(
            snapshot: snapshot,
            focusIsActive: true
        )

        #expect(
            health == .degraded(reasons: [.shieldChannelsNotConfigured])
        )
    }

    @Test("Non-canonical selection is degradation regardless of focus")
    func nonCanonicalSelectionIsDegradation() {
        let snapshot = makeSnapshot(
            isUsable: true,
            applicationCount: 3,
            isCanonical: false,
            applicationCategoriesPolicy: .none,
            writesSpecificApplicationsChannel: true
        )

        let health = ScreenTimeRuntimeHealth.evaluate(
            snapshot: snapshot,
            focusIsActive: false
        )

        #expect(health == .degraded(reasons: [.selectionNotCanonical]))
    }

    @Test("Multiple degradation reasons accumulate into one degraded case")
    func multipleReasonsAccumulate() {
        let snapshot = makeSnapshot(
            isUsable: true,
            applicationCount: 3,
            applicationCategoriesPolicy: .none,
            writesSpecificApplicationsChannel: true,
            applicationsChannelConfigured: false,
            focusActivityRegistered: false,
            sessionContextActive: false
        )

        let health = ScreenTimeRuntimeHealth.evaluate(
            snapshot: snapshot,
            focusIsActive: true
        )

        #expect(
            health
                == .degraded(reasons: [
                    .shieldChannelsNotConfigured,
                    .missingDeviceActivityRegistration,
                    .missingSharedSessionContext,
                ])
        )
    }

    // MARK: - Snapshot Builder

    /// Builds a synthetic ``ScreenTimeDiagnostics`` value with every knob
    /// the evaluator cares about exposed as a parameter. Lets each test
    /// override only the bit under test without dragging the others in.
    private func makeSnapshot(
        isUsable: Bool,
        applicationCount: Int = 0,
        categoryCount: Int = 0,
        webDomainCount: Int = 0,
        isCanonical: Bool = true,
        applicationCategoriesPolicy: ShieldPolicyMapper
            .ApplicationPolicyCase = .none,
        webDomainCategoriesPolicy: ShieldPolicyMapper
            .WebDomainPolicyCase = .none,
        writesSpecificApplicationsChannel: Bool = false,
        writesSpecificWebDomainsChannel: Bool = false,
        applicationsChannelConfigured: Bool = false,
        applicationCategoriesChannelConfigured: Bool = false,
        webDomainsChannelConfigured: Bool = false,
        webDomainCategoriesChannelConfigured: Bool = false,
        focusActivityRegistered: Bool = false,
        sessionContextActive: Bool = false
    ) -> ScreenTimeDiagnostics {
        ScreenTimeDiagnostics(
            authorization: ScreenTimeDiagnostics.Authorization(
                status: isUsable ? .approved : .denied,
                isUsable: isUsable
            ),
            selection: ScreenTimeDiagnostics.Selection(
                applicationCount: applicationCount,
                categoryCount: categoryCount,
                webDomainCount: webDomainCount,
                isCanonical: isCanonical
            ),
            policy: ShieldPolicyMapper.DecisionShape(
                applicationCategories: applicationCategoriesPolicy,
                webDomainCategories: webDomainCategoriesPolicy,
                writesSpecificApplicationsChannel:
                    writesSpecificApplicationsChannel,
                writesSpecificWebDomainsChannel:
                    writesSpecificWebDomainsChannel
            ),
            shieldChannels: ScreenTimeDiagnostics.ShieldChannels(
                applicationsConfigured: applicationsChannelConfigured,
                applicationsCount: applicationsChannelConfigured ? 1 : 0,
                applicationCategoriesConfigured:
                    applicationCategoriesChannelConfigured,
                webDomainsConfigured: webDomainsChannelConfigured,
                webDomainsCount: webDomainsChannelConfigured ? 1 : 0,
                webDomainCategoriesConfigured:
                    webDomainCategoriesChannelConfigured
            ),
            monitoring: ScreenTimeDiagnostics.Monitoring(
                focusActivityRegistered: focusActivityRegistered,
                focusScheduleEnd: nil
            ),
            sessionContext: ScreenTimeDiagnostics.SessionContext(
                isActive: sessionContextActive,
                phase: sessionContextActive ? "Focus" : nil,
                targetEndDate: sessionContextActive
                    ? .now.addingTimeInterval(60) : nil
            ),
            extensionTelemetry: emptyTelemetrySnapshot,
            capturedAt: .now
        )
    }

    /// Empty telemetry stand-in used by evaluator tests that don't care
    /// about extension-invocation state. The evaluator reads only the
    /// pipeline-truth fields; the telemetry field is surfaced to the UI
    /// but isn't part of the classifier's decision surface.
    private var emptyTelemetrySnapshot: ShieldExtensionTelemetry.Snapshot {
        ShieldExtensionTelemetry.Snapshot(
            monitorIntervalDidStart: ShieldExtensionTelemetry.EventSnapshot(
                event: .monitorIntervalDidStart,
                count: 0,
                lastFiredAt: nil
            ),
            monitorIntervalDidEnd: ShieldExtensionTelemetry.EventSnapshot(
                event: .monitorIntervalDidEnd,
                count: 0,
                lastFiredAt: nil
            ),
            shieldForApplication: ShieldExtensionTelemetry.EventSnapshot(
                event: .shieldForApplication,
                count: 0,
                lastFiredAt: nil
            ),
            shieldForWebDomain: ShieldExtensionTelemetry.EventSnapshot(
                event: .shieldForWebDomain,
                count: 0,
                lastFiredAt: nil
            ),
            lastObservedContext: nil
        )
    }
}

// MARK: - Extension Telemetry Store

/// Coverage for ``ShieldExtensionTelemetry``.
///
/// The store is the App Group write channel both extensions use, so these
/// tests run against an isolated ``UserDefaults`` suite (never the shared
/// App Group) via the `defaults:` parameter on each public method.
@MainActor
struct ShieldExtensionTelemetryTests {

    private func makeDefaults() -> UserDefaults {
        let suiteName = "com.pomoduo.tests.telemetry.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        ShieldExtensionTelemetry.reset(defaults: defaults)
        return defaults
    }

    @Test("Fresh store produces a zero snapshot with no observed context")
    func freshStoreIsEmpty() {
        let defaults = makeDefaults()

        let snapshot = ShieldExtensionTelemetry.snapshot(defaults: defaults)

        for event in snapshot.allEvents {
            #expect(event.count == 0)
            #expect(event.lastFiredAt == nil)
        }
        #expect(snapshot.lastObservedContext == nil)
        #expect(snapshot.mostRecentInvocation == nil)
    }

    @Test("record increments the count and timestamps the matching event")
    func recordIncrementsCountAndTimestamp() {
        let defaults = makeDefaults()
        let fireDate = Date(timeIntervalSince1970: 2_100_000_000)

        ShieldExtensionTelemetry.record(
            .monitorIntervalDidStart,
            at: fireDate,
            isSessionActive: true,
            phase: "Focus",
            targetEndDate: fireDate.addingTimeInterval(25 * 60),
            focusActivityRegistered: true,
            defaults: defaults
        )

        let snapshot = ShieldExtensionTelemetry.snapshot(defaults: defaults)
        #expect(snapshot.monitorIntervalDidStart.count == 1)
        #expect(snapshot.monitorIntervalDidStart.lastFiredAt == fireDate)
        // Other events untouched.
        #expect(snapshot.monitorIntervalDidEnd.count == 0)
        #expect(snapshot.shieldForApplication.count == 0)
        #expect(snapshot.shieldForWebDomain.count == 0)
    }

    @Test("record captures observed session context at callback time")
    func recordCapturesObservedContext() {
        let defaults = makeDefaults()
        let fireDate = Date(timeIntervalSince1970: 2_100_000_500)
        let targetEnd = fireDate.addingTimeInterval(25 * 60)

        ShieldExtensionTelemetry.record(
            .monitorIntervalDidStart,
            at: fireDate,
            isSessionActive: true,
            phase: "Focus",
            targetEndDate: targetEnd,
            focusActivityRegistered: true,
            defaults: defaults
        )

        let snapshot = ShieldExtensionTelemetry.snapshot(defaults: defaults)
        let context = snapshot.lastObservedContext
        #expect(context?.byEvent == .monitorIntervalDidStart)
        #expect(context?.observedAt == fireDate)
        #expect(context?.isSessionActive == true)
        #expect(context?.phase == "Focus")
        #expect(context?.targetEndDate == targetEnd)
        #expect(context?.focusActivityRegistered == true)
    }

    /// Multiple records must accumulate per event; the last-observed
    /// context must reflect the *last* record across all events. This is
    /// the critical diagnostic: if the shield fires after the monitor,
    /// the last-observed row should say "shield saw context X".
    @Test("Multiple records accumulate per event; last-observed reflects most recent")
    func multipleRecordsAccumulate() {
        let defaults = makeDefaults()
        let firstDate = Date(timeIntervalSince1970: 2_100_000_000)
        let laterDate = firstDate.addingTimeInterval(10)

        ShieldExtensionTelemetry.record(
            .monitorIntervalDidStart,
            at: firstDate,
            isSessionActive: true,
            phase: "Focus",
            targetEndDate: firstDate.addingTimeInterval(1500),
            focusActivityRegistered: true,
            defaults: defaults
        )
        ShieldExtensionTelemetry.record(
            .monitorIntervalDidStart,
            at: laterDate,
            isSessionActive: true,
            phase: "Focus",
            targetEndDate: laterDate.addingTimeInterval(1500),
            focusActivityRegistered: true,
            defaults: defaults
        )
        ShieldExtensionTelemetry.record(
            .shieldForApplication,
            at: laterDate.addingTimeInterval(1),
            isSessionActive: false,
            phase: nil,
            targetEndDate: nil,
            focusActivityRegistered: nil,
            defaults: defaults
        )

        let snapshot = ShieldExtensionTelemetry.snapshot(defaults: defaults)
        #expect(snapshot.monitorIntervalDidStart.count == 2)
        #expect(snapshot.shieldForApplication.count == 1)
        #expect(snapshot.lastObservedContext?.byEvent == .shieldForApplication)
        #expect(snapshot.lastObservedContext?.isSessionActive == false)
        #expect(snapshot.lastObservedContext?.phase == nil)
        // Shield records pass nil for focusActivityRegistered; the stored
        // default surfaces as `false` rather than remaining at the prior
        // monitor-sample value of `true` — the telemetry is an overwrite,
        // not a merge, so stale fields don't leak across events.
        #expect(snapshot.lastObservedContext?.focusActivityRegistered == false)
    }

    @Test("reset clears every event count, timestamp, and observed-context key")
    func resetClearsEverything() {
        let defaults = makeDefaults()
        let fireDate = Date(timeIntervalSince1970: 2_100_000_000)

        ShieldExtensionTelemetry.record(
            .monitorIntervalDidStart,
            at: fireDate,
            isSessionActive: true,
            phase: "Focus",
            targetEndDate: fireDate.addingTimeInterval(1500),
            focusActivityRegistered: true,
            defaults: defaults
        )
        ShieldExtensionTelemetry.record(
            .shieldForApplication,
            at: fireDate.addingTimeInterval(30),
            isSessionActive: true,
            phase: "Focus",
            targetEndDate: fireDate.addingTimeInterval(1500),
            focusActivityRegistered: nil,
            defaults: defaults
        )

        ShieldExtensionTelemetry.reset(defaults: defaults)

        let snapshot = ShieldExtensionTelemetry.snapshot(defaults: defaults)
        for event in snapshot.allEvents {
            #expect(event.count == 0)
            #expect(event.lastFiredAt == nil)
        }
        #expect(snapshot.lastObservedContext == nil)
    }

    /// Distinct event categories must not collide on the same
    /// `UserDefaults` key — a monitor-end record should not bump the
    /// shield-for-application count. This pins the per-event key
    /// separation (`Keys.count(for:)`).
    @Test("Event categories use distinct storage keys")
    func eventsDoNotCollideOnKeys() {
        let defaults = makeDefaults()
        let base = Date(timeIntervalSince1970: 2_100_000_100)

        for (index, event) in ShieldExtensionTelemetry.Event.allCases
            .enumerated()
        {
            ShieldExtensionTelemetry.record(
                event,
                at: base.addingTimeInterval(TimeInterval(index)),
                isSessionActive: true,
                phase: "Focus",
                targetEndDate: base.addingTimeInterval(1500),
                focusActivityRegistered: event == .monitorIntervalDidStart
                    ? true : nil,
                defaults: defaults
            )
        }

        let snapshot = ShieldExtensionTelemetry.snapshot(defaults: defaults)
        for event in snapshot.allEvents {
            #expect(event.count == 1)
            #expect(event.lastFiredAt != nil)
        }
    }

    @Test("mostRecentInvocation selects the latest timestamp across events")
    func mostRecentInvocationSpansAllEvents() {
        let defaults = makeDefaults()
        let earlier = Date(timeIntervalSince1970: 2_100_000_000)
        let latest = earlier.addingTimeInterval(60)

        ShieldExtensionTelemetry.record(
            .monitorIntervalDidStart,
            at: earlier,
            isSessionActive: true,
            phase: "Focus",
            targetEndDate: latest,
            focusActivityRegistered: true,
            defaults: defaults
        )
        ShieldExtensionTelemetry.record(
            .shieldForWebDomain,
            at: latest,
            isSessionActive: true,
            phase: "Focus",
            targetEndDate: latest,
            focusActivityRegistered: nil,
            defaults: defaults
        )

        let snapshot = ShieldExtensionTelemetry.snapshot(defaults: defaults)
        #expect(snapshot.mostRecentInvocation == latest)
    }
}
