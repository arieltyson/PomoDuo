import Foundation
import Testing

@testable import PomoDuo

@MainActor
struct RestrictionCoordinatorTests {
    @Test func initialStateIsNotRestricting() {
        let manager = ScreenTimeManager()
        let coordinator = RestrictionCoordinator(
            screenTimeManager: manager,
            restrictionService: MockRestrictionService(),
            canRestrictEvaluator: { true }
        )

        #expect(coordinator.isRestricting == false)
        #expect(coordinator.lastError == nil)
    }

    @Test func enforceNoOpsWhenCannotRestrict() async throws {
        let manager = ScreenTimeManager()
        let service = MockRestrictionService()
        let coordinator = RestrictionCoordinator(
            screenTimeManager: manager,
            restrictionService: service,
            canRestrictEvaluator: { false }
        )

        coordinator.enforceFocusRestrictions()
        try await Task.sleep(for: .milliseconds(60))

        #expect(await service.applyCallCount == 0)
        #expect(coordinator.isRestricting == false)
    }

    @Test func enforceAppliesRestrictionsWhenEligible() async throws {
        let manager = ScreenTimeManager()
        let service = MockRestrictionService()
        let coordinator = RestrictionCoordinator(
            screenTimeManager: manager,
            restrictionService: service,
            canRestrictEvaluator: { true }
        )

        coordinator.enforceFocusRestrictions()
        try await Task.sleep(for: .milliseconds(60))

        #expect(await service.applyCallCount == 1)
        #expect(coordinator.isRestricting)
        #expect(coordinator.lastError == nil)
    }

    @Test func enforceDoesNotApplyTwiceWhenAlreadyRestricting() async throws {
        let manager = ScreenTimeManager()
        let service = MockRestrictionService()
        let coordinator = RestrictionCoordinator(
            screenTimeManager: manager,
            restrictionService: service,
            canRestrictEvaluator: { true }
        )

        coordinator.enforceFocusRestrictions()
        try await Task.sleep(for: .milliseconds(60))
        coordinator.enforceFocusRestrictions()
        try await Task.sleep(for: .milliseconds(60))

        #expect(await service.applyCallCount == 1)
        #expect(coordinator.isRestricting)
    }

    @Test func liftNoOpsWhenNotRestricting() async throws {
        let manager = ScreenTimeManager()
        let service = MockRestrictionService()
        let coordinator = RestrictionCoordinator(
            screenTimeManager: manager,
            restrictionService: service,
            canRestrictEvaluator: { true }
        )

        coordinator.liftRestrictions()
        try await Task.sleep(for: .milliseconds(60))

        #expect(await service.removeCallCount == 0)
    }

    @Test func liftRemovesRestrictionsWhenActive() async throws {
        let manager = ScreenTimeManager()
        let service = MockRestrictionService()
        let coordinator = RestrictionCoordinator(
            screenTimeManager: manager,
            restrictionService: service,
            canRestrictEvaluator: { true }
        )

        coordinator.enforceFocusRestrictions()
        try await Task.sleep(for: .milliseconds(60))
        coordinator.liftRestrictions()
        try await Task.sleep(for: .milliseconds(60))

        #expect(await service.applyCallCount == 1)
        #expect(await service.removeCallCount == 1)
        #expect(coordinator.isRestricting == false)
    }

    @Test func forceRemoveAlwaysCallsService() async throws {
        let manager = ScreenTimeManager()
        let service = MockRestrictionService()
        let coordinator = RestrictionCoordinator(
            screenTimeManager: manager,
            restrictionService: service,
            canRestrictEvaluator: { false }
        )

        coordinator.forceRemoveRestrictions()
        try await Task.sleep(for: .milliseconds(60))

        #expect(await service.removeCallCount == 1)
        #expect(coordinator.isRestricting == false)
    }

    @Test func applyFailureSetsLastError() async throws {
        let manager = ScreenTimeManager()
        let service = MockRestrictionService()
        await service.setApplyError(NSError(domain: "tests", code: 41))
        let coordinator = RestrictionCoordinator(
            screenTimeManager: manager,
            restrictionService: service,
            canRestrictEvaluator: { true }
        )

        coordinator.enforceFocusRestrictions()

        // Poll briefly — the inner Task must hop to the mock actor
        // (to throw) and back to @MainActor (to set lastError).
        for _ in 0..<20 {
            try await Task.sleep(for: .milliseconds(20))
            if coordinator.lastError != nil { break }
        }

        #expect(await service.applyCallCount == 0)
        #expect(coordinator.isRestricting == false)
        #expect(coordinator.lastError != nil)
    }

    @Test func removeFailureKeepsRestrictingStateAndSetsError() async throws {
        let manager = ScreenTimeManager()
        let service = MockRestrictionService()
        let coordinator = RestrictionCoordinator(
            screenTimeManager: manager,
            restrictionService: service,
            canRestrictEvaluator: { true }
        )

        coordinator.enforceFocusRestrictions()
        try await Task.sleep(for: .milliseconds(60))
        await service.setRemoveError(NSError(domain: "tests", code: 99))

        coordinator.liftRestrictions()
        try await Task.sleep(for: .milliseconds(60))

        #expect(await service.removeCallCount == 0)
        #expect(coordinator.isRestricting)
        #expect(coordinator.lastError != nil)
    }
}
