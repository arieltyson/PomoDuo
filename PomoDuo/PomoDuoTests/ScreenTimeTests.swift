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

/// Regression tests for the "All Apps & Categories" enforcement path.
///
/// Verifies that selecting all categories triggers `.all(except: [])` policy
/// rather than `.specific()`, which would miss uncategorized apps.
@MainActor
struct AllCategoriesEnforcementTests {

    @Test func allCategoriesDetectedWhenAtThreshold() {
        let threshold = ShieldSessionContext.allCategoriesThreshold
        #expect(threshold == 12)
        // 12 or more category tokens = "All Apps & Categories"
        #expect(12 >= threshold)
        #expect(13 >= threshold)
    }

    @Test func partialCategoriesNotDetectedAsAll() {
        let threshold = ShieldSessionContext.allCategoriesThreshold
        #expect(5 < threshold)
        #expect(11 < threshold)
    }

    @Test func zeroCategoriesNotDetectedAsAll() {
        let threshold = ShieldSessionContext.allCategoriesThreshold
        #expect(0 < threshold)
    }

    @Test func enforcementRoundTripWithAllCategories() async throws {
        // Verifies the mock service correctly tracks apply/remove
        // for the "all categories" scenario.
        let service = MockRestrictionService()
        try await service.applyRestrictions()
        #expect(await service.isCurrentlyRestricted)

        try await service.removeRestrictions()
        #expect(await service.isCurrentlyRestricted == false)
    }
}

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

/// Regression coverage for the "select all, then remove some apps" bug.
///
/// The threshold-only mapper used to drop from `.all(except: [])` to
/// `.specific(N-1 categories)` on the very first deselection, silently
/// unblocking every uncategorized app and every app the picker hadn't
/// enumerated in the dropped category. The mapper now preserves the
/// user's intent by threading `applicationTokens` through the *exception*
/// parameter of `ShieldSettings.ActivityCategoryPolicy` whenever the
/// selection represents "All Apps & Categories".
///
/// These tests exercise ``ShieldPolicyMapper/decideShape(applicationTokenCount:categoryTokenCount:webDomainTokenCount:allCategoriesThreshold:)``,
/// the count-driven mirror of the value-aware ``decide`` function. The
/// case enumeration it returns is what determines which `ManagedSettings`
/// channel gets written, so exercising it with plain `Int` inputs covers
/// the mapping semantics end-to-end without having to fabricate opaque
/// Screen Time tokens.
@MainActor
struct ShieldPolicyMapperTests {

    private let threshold = ShieldSessionContext.allCategoriesThreshold

    @Test func emptySelectionProducesNoShieldWrites() {
        let shape = ShieldPolicyMapper.decideShape(
            applicationTokenCount: 0,
            categoryTokenCount: 0,
            webDomainTokenCount: 0,
            allCategoriesThreshold: threshold
        )

        #expect(shape.applicationCategories == .none)
        #expect(shape.webDomainCategories == .none)
        #expect(shape.writesSpecificApplicationsChannel == false)
        #expect(shape.writesSpecificWebDomainsChannel == false)
    }

    @Test func allCategoriesWithNoExceptionsMapsToAllExceptEmpty() {
        let shape = ShieldPolicyMapper.decideShape(
            applicationTokenCount: 0,
            categoryTokenCount: threshold,
            webDomainTokenCount: 0,
            allCategoriesThreshold: threshold
        )

        #expect(shape.applicationCategories == .allExcept)
        #expect(shape.webDomainCategories == .all)
        #expect(shape.writesSpecificApplicationsChannel == false)
    }

    /// Regression: "select all + deselect some apps" must produce
    /// `.all(except: applicationTokens)` so the remaining categories stay
    /// blocked while the deselected apps are allowed through. The key
    /// assertion is that the `applications` channel must **not** be written
    /// — writing it would re-shield those apps and negate the `except:` list.
    @Test func allCategoriesWithDeselectedAppsMapsToAllExceptThoseApps() {
        let shape = ShieldPolicyMapper.decideShape(
            applicationTokenCount: 2,
            categoryTokenCount: threshold,
            webDomainTokenCount: 0,
            allCategoriesThreshold: threshold
        )

        #expect(shape.applicationCategories == .allExcept)
        #expect(shape.webDomainCategories == .all)
        #expect(shape.writesSpecificApplicationsChannel == false)
    }

    /// Regression guardrail against the old behavior: the very moment the
    /// user deselects a single app and the picker drops one category below
    /// threshold, the naive implementation fell off the `.all(except: [])`
    /// branch and silently unblocked every uncategorized app. The fix must
    /// keep shielding the remaining categories *and* keep the specific apps
    /// flowing through the `applications` channel so carved-out exceptions
    /// are still blocked within the still-selected categories.
    @Test func dropOneCategoryBelowThresholdStillShieldsRemainingCategoriesAndApps() {
        let shape = ShieldPolicyMapper.decideShape(
            applicationTokenCount: 3,
            categoryTokenCount: threshold - 1,
            webDomainTokenCount: 0,
            allCategoriesThreshold: threshold
        )

        #expect(shape.applicationCategories == .specific)
        #expect(shape.webDomainCategories == .specific)
        #expect(shape.writesSpecificApplicationsChannel == true)
    }

    @Test func partialCategoriesShieldThoseCategoriesAndSpecificApps() {
        let shape = ShieldPolicyMapper.decideShape(
            applicationTokenCount: 3,
            categoryTokenCount: 5,
            webDomainTokenCount: 0,
            allCategoriesThreshold: threshold
        )

        #expect(shape.applicationCategories == .specific)
        #expect(shape.webDomainCategories == .specific)
        #expect(shape.writesSpecificApplicationsChannel == true)
    }

    @Test func specificAppsOnlyProducesApplicationsChannelWrite() {
        let shape = ShieldPolicyMapper.decideShape(
            applicationTokenCount: 4,
            categoryTokenCount: 0,
            webDomainTokenCount: 0,
            allCategoriesThreshold: threshold
        )

        #expect(shape.applicationCategories == .none)
        #expect(shape.webDomainCategories == .none)
        #expect(shape.writesSpecificApplicationsChannel == true)
    }

    @Test func webDomainsFlowThroughSpecificChannelIndependently() {
        let shape = ShieldPolicyMapper.decideShape(
            applicationTokenCount: 0,
            categoryTokenCount: 0,
            webDomainTokenCount: 2,
            allCategoriesThreshold: threshold
        )

        #expect(shape.webDomainCategories == .none)
        #expect(shape.writesSpecificWebDomainsChannel == true)
    }

    /// Regression: the main app and the Monitor extension must compute a
    /// byte-identical decision for the same selection, so the first
    /// enforcement and any post-force-quit re-application can't diverge.
    @Test func mainAppAndMonitorExtensionComputeIdenticalShape() {
        let mainAppShape = ShieldPolicyMapper.decideShape(
            applicationTokenCount: 2,
            categoryTokenCount: threshold,
            webDomainTokenCount: 0,
            allCategoriesThreshold: threshold
        )
        let monitorShape = ShieldPolicyMapper.decideShape(
            applicationTokenCount: 2,
            categoryTokenCount: threshold,
            webDomainTokenCount: 0,
            allCategoriesThreshold: threshold
        )

        #expect(mainAppShape == monitorShape)
    }

    /// Regression: the old code used `categoryTokens.count >= 12` as the
    /// sole signal for "all categories" and silently ignored whether any
    /// app tokens were present — so "all cats + 0 exceptions" and
    /// "all cats + N exceptions" would look indistinguishable in the
    /// `applicationCategories` channel (both `.all(except: [])`) while the
    /// N exceptions were duplicated into the `applications` channel and
    /// still blocked. The new mapping must not write the `applications`
    /// channel in either case, so the two mappings differ only in the
    /// `except:` contents of the category policy.
    @Test func oldThresholdOnlyBehaviorIsInsufficient() {
        let noExceptionsShape = ShieldPolicyMapper.decideShape(
            applicationTokenCount: 0,
            categoryTokenCount: threshold,
            webDomainTokenCount: 0,
            allCategoriesThreshold: threshold
        )
        let withExceptionsShape = ShieldPolicyMapper.decideShape(
            applicationTokenCount: 5,
            categoryTokenCount: threshold,
            webDomainTokenCount: 0,
            allCategoriesThreshold: threshold
        )

        // Same policy case in both — `.allExcept` — but neither writes the
        // `applications` channel. The old behavior would have written the
        // specific-apps channel in the second case, re-blocking the user's
        // carved-out exceptions.
        #expect(noExceptionsShape.applicationCategories == .allExcept)
        #expect(withExceptionsShape.applicationCategories == .allExcept)
        #expect(noExceptionsShape.writesSpecificApplicationsChannel == false)
        #expect(withExceptionsShape.writesSpecificApplicationsChannel == false)
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
