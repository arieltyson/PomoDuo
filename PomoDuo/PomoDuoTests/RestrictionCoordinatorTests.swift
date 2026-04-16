import Foundation
import ManagedSettings
import Testing

@testable import PomoDuo

/// Mutable box for toggling `canRestrict` eligibility in tests
/// without triggering sendable-capture warnings on a local `var`.
@MainActor
private final class MutableEligibility {
    var value = true
}

@MainActor
struct RestrictionCoordinatorTests {

    /// Stable end date used by enforce calls in tests so the comparison
    /// against ``ShieldSessionContext.targetEndDate`` is deterministic.
    private static let sampleEndDate = Date(timeIntervalSince1970: 2_500_000_000)

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
        let manager = ScreenTimeManager(store: ManagedSettingsStore())
        let coordinator = RestrictionCoordinator(
            screenTimeManager: manager,
            restrictionService: MockRestrictionService(),
            canRestrictEvaluator: { true }
        )

        #expect(coordinator.isRestricting == false)
        #expect(coordinator.lastError == nil)
    }

    @Test func enforceNoOpsWhenCannotRestrict() async throws {
        let manager = ScreenTimeManager(store: ManagedSettingsStore())
        let service = MockRestrictionService()
        let coordinator = RestrictionCoordinator(
            screenTimeManager: manager,
            restrictionService: service,
            canRestrictEvaluator: { false }
        )

        coordinator.enforceFocusRestrictions(until: Self.sampleEndDate)
        try await waitUntil {
            coordinator.lastError != nil || coordinator.isRestricting
        }

        #expect(await service.applyCallCount == 0)
        #expect(coordinator.isRestricting == false)
    }

    @Test func enforceAppliesRestrictionsWhenEligible() async throws {
        let manager = ScreenTimeManager(store: ManagedSettingsStore())
        let service = MockRestrictionService()
        let coordinator = RestrictionCoordinator(
            screenTimeManager: manager,
            restrictionService: service,
            canRestrictEvaluator: { true }
        )

        coordinator.enforceFocusRestrictions(until: Self.sampleEndDate)
        try await waitUntil { coordinator.isRestricting }

        #expect(await service.applyCallCount == 1)
        #expect(coordinator.isRestricting)
        #expect(coordinator.lastError == nil)
    }

    @Test func enforceDoesNotApplyTwiceWhenAlreadyRestricting() async throws {
        let manager = ScreenTimeManager(store: ManagedSettingsStore())
        let service = MockRestrictionService()
        let coordinator = RestrictionCoordinator(
            screenTimeManager: manager,
            restrictionService: service,
            canRestrictEvaluator: { true }
        )

        coordinator.enforceFocusRestrictions(until: Self.sampleEndDate)
        try await waitUntil { coordinator.isRestricting }
        coordinator.enforceFocusRestrictions(until: Self.sampleEndDate)
        try await Task.sleep(for: .milliseconds(60))

        #expect(await service.applyCallCount == 1)
        #expect(coordinator.isRestricting)
    }

    @Test func liftNoOpsWhenNotRestricting() async throws {
        let manager = ScreenTimeManager(store: ManagedSettingsStore())
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
        let manager = ScreenTimeManager(store: ManagedSettingsStore())
        let service = MockRestrictionService()
        let coordinator = RestrictionCoordinator(
            screenTimeManager: manager,
            restrictionService: service,
            canRestrictEvaluator: { true }
        )

        coordinator.enforceFocusRestrictions(until: Self.sampleEndDate)
        try await waitUntil { coordinator.isRestricting }

        coordinator.liftRestrictions()
        try await waitUntil { !coordinator.isRestricting }

        #expect(await service.applyCallCount == 1)
        #expect(await service.removeCallCount == 1)
        #expect(coordinator.isRestricting == false)
    }

    @Test func forceRemoveAlwaysCallsService() async throws {
        let manager = ScreenTimeManager(store: ManagedSettingsStore())
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
        let manager = ScreenTimeManager(store: ManagedSettingsStore())
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
        let manager = ScreenTimeManager(store: ManagedSettingsStore())
        let service = MockRestrictionService()
        let coordinator = RestrictionCoordinator(
            screenTimeManager: manager,
            restrictionService: service,
            canRestrictEvaluator: { true }
        )

        coordinator.enforceFocusRestrictions(until: Self.sampleEndDate)
        try await waitUntil { coordinator.isRestricting }

        coordinator.refreshRestrictions()
        try await waitUntil { await service.applyCallCount == 2 }

        #expect(await service.applyCallCount == 2)
        #expect(coordinator.isRestricting)
        #expect(coordinator.lastError == nil)
    }

    @Test func refreshRemovesRestrictionsWhenSelectionCleared() async throws {
        let manager = ScreenTimeManager(store: ManagedSettingsStore())
        let service = MockRestrictionService()
        let eligibility = MutableEligibility()
        let coordinator = RestrictionCoordinator(
            screenTimeManager: manager,
            restrictionService: service,
            canRestrictEvaluator: { eligibility.value }
        )

        // Start restricting.
        coordinator.enforceFocusRestrictions(until: Self.sampleEndDate)
        try await waitUntil { coordinator.isRestricting }
        #expect(coordinator.isRestricting)

        // Simulate user clearing all selections (canRestrict becomes false).
        eligibility.value = false
        coordinator.refreshRestrictions()
        try await waitUntil { !coordinator.isRestricting }

        #expect(coordinator.isRestricting == false)
        #expect(await service.removeCallCount == 1)
    }

    @Test func refreshReappliesWhenSelectionShrinks() async throws {
        let manager = ScreenTimeManager(store: ManagedSettingsStore())
        let service = MockRestrictionService()
        let coordinator = RestrictionCoordinator(
            screenTimeManager: manager,
            restrictionService: service,
            canRestrictEvaluator: { true }
        )

        // Start restricting.
        coordinator.enforceFocusRestrictions(until: Self.sampleEndDate)
        try await waitUntil { coordinator.isRestricting }

        // Simulate removing one app (canRestrict still true).
        coordinator.refreshRestrictions()
        try await waitUntil { await service.applyCallCount == 2 }

        #expect(await service.applyCallCount == 2)
        #expect(await service.removeCallCount == 0)
        #expect(coordinator.isRestricting)
    }

    @Test func applyFailureSetsLastError() async throws {
        let manager = ScreenTimeManager(store: ManagedSettingsStore())
        let service = MockRestrictionService()
        await service.setApplyError(NSError(domain: "tests", code: 41))
        let coordinator = RestrictionCoordinator(
            screenTimeManager: manager,
            restrictionService: service,
            canRestrictEvaluator: { true }
        )

        coordinator.enforceFocusRestrictions(until: Self.sampleEndDate)
        try await waitUntil { coordinator.lastError != nil }

        #expect(await service.applyCallCount == 0)
        #expect(coordinator.isRestricting == false)
        #expect(coordinator.lastError != nil)
    }

    @Test func removeFailureKeepsRestrictingStateAndSetsError() async throws {
        let manager = ScreenTimeManager(store: ManagedSettingsStore())
        let service = MockRestrictionService()
        let coordinator = RestrictionCoordinator(
            screenTimeManager: manager,
            restrictionService: service,
            canRestrictEvaluator: { true }
        )

        coordinator.enforceFocusRestrictions(until: Self.sampleEndDate)
        try await waitUntil { coordinator.isRestricting }

        await service.setRemoveError(NSError(domain: "tests", code: 99))

        coordinator.liftRestrictions()
        try await waitUntil { coordinator.lastError != nil }

        #expect(await service.removeCallCount == 0)
        #expect(coordinator.isRestricting)
        #expect(coordinator.lastError != nil)
    }
}

// MARK: - Full Pipeline Coverage

/// Spy that records the coordinator's context writes without touching the
/// process-global App Group `UserDefaults` that backs the real
/// ``ShieldSessionContext``.
///
/// Reading `UserDefaults` from multiple parallel test suites races, so
/// routing writes through an injected spy is the only way to verify
/// coordinator behavior deterministically.
@MainActor
private final class SpyFocusSessionContextWriter: FocusSessionContextWriting {
    private(set) var lastWrittenEndDate: Date?
    private(set) var writeCount = 0
    private(set) var clearCount = 0

    func writeFocus(targetEndDate: Date) {
        lastWrittenEndDate = targetEndDate
        writeCount += 1
    }

    func clearFocus() {
        lastWrittenEndDate = nil
        clearCount += 1
    }
}

/// Regression coverage for the bug where the solo focus flow set the
/// in-process shield but never wrote shared session context or registered
/// DeviceActivity monitoring — leaving the OS with no extension-backed
/// re-applier and the user able to launch supposedly-blocked apps.
@MainActor
struct RestrictionCoordinatorPipelineTests {

    private static let sampleEndDate = Date(timeIntervalSince1970: 2_500_000_500)

    private func waitUntil(
        timeout: Int = 40,
        _ condition: @MainActor () async -> Bool
    ) async throws {
        for _ in 0..<timeout {
            if await condition() { return }
            try await Task.sleep(for: .milliseconds(20))
        }
    }

    @Test func enforceWritesSessionContextWithEndDate() async throws {
        let manager = ScreenTimeManager(store: ManagedSettingsStore())
        let service = MockRestrictionService()
        let spy = SpyFocusSessionContextWriter()
        let coordinator = RestrictionCoordinator(
            screenTimeManager: manager,
            restrictionService: service,
            sessionContextWriter: spy,
            canRestrictEvaluator: { true }
        )

        coordinator.enforceFocusRestrictions(until: Self.sampleEndDate)
        try await waitUntil { coordinator.isRestricting }

        #expect(spy.writeCount == 1)
        #expect(spy.lastWrittenEndDate == Self.sampleEndDate)
        #expect(spy.clearCount == 0)
        #expect(coordinator.isRestricting)
    }

    @Test func liftClearsSessionContext() async throws {
        let manager = ScreenTimeManager(store: ManagedSettingsStore())
        let service = MockRestrictionService()
        let spy = SpyFocusSessionContextWriter()
        let coordinator = RestrictionCoordinator(
            screenTimeManager: manager,
            restrictionService: service,
            sessionContextWriter: spy,
            canRestrictEvaluator: { true }
        )

        coordinator.enforceFocusRestrictions(until: Self.sampleEndDate)
        try await waitUntil { coordinator.isRestricting }

        coordinator.liftRestrictions()
        try await waitUntil { !coordinator.isRestricting }

        #expect(spy.writeCount == 1)
        #expect(spy.clearCount == 1)
        #expect(spy.lastWrittenEndDate == nil)
    }

    @Test func forceRemoveAlwaysClearsContextEvenOnRemovalError() async throws {
        let manager = ScreenTimeManager(store: ManagedSettingsStore())
        let service = MockRestrictionService()
        await service.setRemoveError(NSError(domain: "tests", code: 7))
        let spy = SpyFocusSessionContextWriter()

        let coordinator = RestrictionCoordinator(
            screenTimeManager: manager,
            restrictionService: service,
            sessionContextWriter: spy,
            canRestrictEvaluator: { false }
        )

        coordinator.forceRemoveRestrictions()
        try await waitUntil { coordinator.lastError != nil }

        // Even though removeRestrictions threw, the safety-net teardown of
        // shared context must still run so the Monitor extension cannot
        // re-assert shields against a stale session.
        #expect(spy.clearCount == 1)
        #expect(coordinator.lastError != nil)
    }
}
