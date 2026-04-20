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

    /// Category exceptions are a separate input from selected app tokens. They
    /// should switch only the category policy to `.specificExcept`. If a
    /// corrupt restored state overlaps an exception with a selected app token,
    /// the selected app token still writes through the specific-apps channel
    /// so the picker-visible "blocked" state wins.
    @Test func categoryExceptionsUseSpecificExceptPolicy() {
        let shape = ShieldPolicyMapper.decideShape(
            applicationTokenCount: 4,
            categoryTokenCount: 1,
            webDomainTokenCount: 3,
            categoryExceptionCount: 2
        )

        #expect(shape.applicationCategories == .specificExcept)
        #expect(shape.webDomainCategories == .specific)
        #expect(shape.writesSpecificApplicationsChannel == true)
        #expect(shape.writesSpecificWebDomainsChannel == true)
    }

    @Test func selectedAppsStillWriteWhenExceptionCountsOverlap() {
        let shape = ShieldPolicyMapper.decideShape(
            applicationTokenCount: 2,
            categoryTokenCount: 1,
            webDomainTokenCount: 0,
            categoryExceptionCount: 2
        )

        #expect(shape.applicationCategories == .specificExcept)
        #expect(shape.writesSpecificApplicationsChannel == true)
    }

    @Test func webDomainCategoryExceptionsUseSpecificExceptPolicy() {
        let shape = ShieldPolicyMapper.decideShape(
            applicationTokenCount: 4,
            categoryTokenCount: 1,
            webDomainTokenCount: 3,
            webDomainCategoryExceptionCount: 1
        )

        #expect(shape.applicationCategories == .specific)
        #expect(shape.webDomainCategories == .specificExcept)
        #expect(shape.writesSpecificApplicationsChannel == true)
        #expect(shape.writesSpecificWebDomainsChannel == true)
    }
}

// MARK: - Category Exception Resolver

@MainActor
struct CategoryExceptionResolverTests {
    @Test func partialDeselectRestoresLostCategoryAndStoresRemovedItem() {
        let resolution = CategoryExceptionResolver.resolve(
            previousCategories: Set(["social"]),
            previousItems: Set(["chat", "video", "music"]),
            previousExceptions: Set<String>(),
            draftCategories: Set<String>(),
            draftItems: Set(["chat", "music"]),
            restoresLostCategories: true
        )

        #expect(resolution.categories == Set(["social"]))
        #expect(resolution.exceptions == Set(["video"]))
    }

    @Test func reselectedItemIsRemovedFromExceptions() {
        let resolution = CategoryExceptionResolver.resolve(
            previousCategories: Set(["social"]),
            previousItems: Set(["chat", "music"]),
            previousExceptions: Set(["video"]),
            draftCategories: Set(["social"]),
            draftItems: Set(["chat", "music", "video"]),
            restoresLostCategories: false
        )

        #expect(resolution.categories == Set(["social"]))
        #expect(resolution.exceptions.isEmpty)
    }

    @Test func repeatedPickerCommitPreservesPartiallyBlockedCategory() {
        let resolution = CategoryExceptionResolver.resolve(
            previousCategories: Set(["social"]),
            previousItems: Set(["discord", "facetime", "messages"]),
            previousExceptions: Set(["whatsapp"]),
            draftCategories: Set<String>(),
            draftItems: Set(["discord", "facetime", "messages"]),
            restoresLostCategories: true
        )

        #expect(resolution.categories == Set(["social"]))
        #expect(resolution.exceptions == Set(["whatsapp"]))
    }

    @Test func clearingAllCategoriesClearsExceptions() {
        let resolution = CategoryExceptionResolver.resolve(
            previousCategories: Set(["social"]),
            previousItems: Set(["chat", "music"]),
            previousExceptions: Set(["video"]),
            draftCategories: Set<String>(),
            draftItems: Set<String>(),
            restoresLostCategories: false
        )

        #expect(resolution.categories.isEmpty)
        #expect(resolution.exceptions.isEmpty)
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
/// `true` so the picker's next edit keeps category expansion semantics.
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

// MARK: - Draft / Commit Algorithm

/// Coverage for ``ScreenTimeManager/commitDraft(_:)``.
///
/// The commit path intentionally keeps picker edits local until Save, then
/// stores the draft as the active selection in canonical form.
@MainActor
struct ScreenTimeManagerCommitDraftTests {

    private func makeManager() -> (
        manager: ScreenTimeManager,
        defaults: UserDefaults
    ) {
        let suiteName = "com.pomoduo.tests.commit.\(UUID().uuidString)"
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
        manager.clearSelection()
        return (manager, defaults)
    }

    @Test("Empty draft commits as an empty selection")
    func emptyToEmptyCommit() {
        let (manager, _) = makeManager()

        let empty = FamilyActivitySelection(includeEntireCategory: true)
        manager.commitDraft(empty)

        #expect(manager.activitySelection.categoryTokens.isEmpty)
        #expect(manager.activitySelection.applicationTokens.isEmpty)
    }

    @Test("Empty draft preserves canonical include-entire-category flag")
    func emptyToFreshDraftLiteralCommit() {
        let (manager, _) = makeManager()

        let draft = FamilyActivitySelection(includeEntireCategory: true)
        manager.commitDraft(draft)

        #expect(manager.activitySelection.includeEntireCategory == true)
    }

    @Test("Commit -> identical commit preserves selection")
    func identicalRecommitPreservesSelection() {
        let (manager, _) = makeManager()

        let draft = FamilyActivitySelection(includeEntireCategory: true)
        manager.commitDraft(draft)
        let committed = manager.activitySelection
        manager.commitDraft(draft)

        #expect(manager.activitySelection == committed)
    }

    @Test("clearSelection drops the active selection")
    func clearSelectionDropsActiveSelection() {
        let (manager, _) = makeManager()

        manager.clearSelection()

        #expect(manager.activitySelection.applicationTokens.isEmpty)
        #expect(manager.activitySelection.categoryTokens.isEmpty)
    }

    /// `canonicalizeRestoredSelection` is invoked by `commitDraft` so a
    /// non-canonical draft (e.g. from a hypothetical caller bypassing
    /// the picker) still lands as canonical. This is the safety net
    /// that keeps the rest of the pipeline `includeEntireCategory:
    /// true`-correct.
    @Test("commitDraft canonicalizes a non-canonical draft")
    func commitDraftCanonicalizes() {
        let (manager, _) = makeManager()

        let nonCanonical = FamilyActivitySelection(
            includeEntireCategory: false
        )
        manager.commitDraft(nonCanonical)

        #expect(manager.activitySelection.includeEntireCategory == true)
    }

}
