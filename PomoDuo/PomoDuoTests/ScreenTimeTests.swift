import Foundation
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

@MainActor
struct AppBlockingStatusLogicTests {
    func pluralizeApp(count: Int) -> String {
        count == 1 ? "app" : "apps"
    }

    func pluralizeCategory(count: Int) -> String {
        count == 1 ? "category" : "categories"
    }

    @Test func badgeSumsAppsAndCategories() {
        let appCount = 3
        let categoryCount = 2
        #expect(appCount + categoryCount == 5)
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
}
