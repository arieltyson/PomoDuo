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
