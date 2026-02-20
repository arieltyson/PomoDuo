import Foundation
import Testing

@testable import PomoDuo

@MainActor
struct RestrictionCoordinatorTests {

    /// Polls a condition up to ~400ms, yielding between checks so the
    /// coordinator's inner `Task` can complete its actor round-trip.
    private func waitUntil(
        timeout: Int = 20,
        _ condition: @MainActor () async -> Bool
    ) async throws {
        for _ in 0..<timeout {
            if await condition() { return }
            try await Task.sleep(for: .milliseconds(20))
        }
    }

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
        try await waitUntil {
            coordinator.lastError != nil || coordinator.isRestricting
        }

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
        try await waitUntil { coordinator.isRestricting }

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
        try await waitUntil { coordinator.isRestricting }
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
        try await waitUntil { coordinator.isRestricting }

        coordinator.liftRestrictions()
        try await waitUntil { !coordinator.isRestricting }

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
        try await waitUntil { await service.removeCallCount == 1 }

        #expect(await service.removeCallCount == 1)
        #expect(coordinator.isRestricting == false)
    }

    @Test func refreshNoOpsWhenNotRestricting() async throws {
        let manager = ScreenTimeManager()
        let service = MockRestrictionService()
        let coordinator = RestrictionCoordinator(
            screenTimeManager: manager,
            restrictionService: service,
            canRestrictEvaluator: { true }
        )

        coordinator.refreshRestrictions()
        try await Task.sleep(for: .milliseconds(60))

        #expect(await service.applyCallCount == 0)
        #expect(coordinator.isRestricting == false)
    }

    @Test func refreshReappliesRestrictionsWhenActive() async throws {
        let manager = ScreenTimeManager()
        let service = MockRestrictionService()
        let coordinator = RestrictionCoordinator(
            screenTimeManager: manager,
            restrictionService: service,
            canRestrictEvaluator: { true }
        )

        coordinator.enforceFocusRestrictions()
        try await waitUntil { coordinator.isRestricting }

        coordinator.refreshRestrictions()
        try await waitUntil { await service.applyCallCount == 2 }

        #expect(await service.applyCallCount == 2)
        #expect(coordinator.isRestricting)
        #expect(coordinator.lastError == nil)
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
        try await waitUntil { coordinator.lastError != nil }

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
        try await waitUntil { coordinator.isRestricting }

        await service.setRemoveError(NSError(domain: "tests", code: 99))

        coordinator.liftRestrictions()
        try await waitUntil { coordinator.lastError != nil }

        #expect(await service.removeCallCount == 0)
        #expect(coordinator.isRestricting)
        #expect(coordinator.lastError != nil)
    }
}
