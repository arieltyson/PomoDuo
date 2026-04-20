import Foundation
import ManagedSettings
import Testing

@testable import PomoDuo

/// Side-effect coverage for the consolidated paired Screen Time path.
///
/// After the ownership consolidation, ``SessionManager`` no longer owns
/// `RestrictionService` / `FocusActivityScheduler` / `ShieldSessionContext`
/// directly. Every paired Screen Time write is delegated to a real
/// ``RestrictionCoordinator``, which serialises through its `pendingTask`
/// queue and forwards apply/remove to the injected ``RestrictionService``.
///
/// The assertions still observe the call counts on the mock service — they
/// just observe them via the consolidated coordinator path, which is what
/// a real remote update now exercises end-to-end.
@Suite("SessionManager Remote Sync Side Effects")
@MainActor
struct SessionManagerRemoteSyncTests {
    private func makeSession(
        id: String = "session-1",
        state: SessionState = .idle,
        isPaused: Bool = false,
        pausedBy: String? = nil,
        targetEndDate: Date = .now.addingTimeInterval(25 * 60)
    ) -> StudySession {
        StudySession(
            id: id,
            partnerA: "user-a",
            partnerB: "user-b",
            state: state,
            startTime: .now,
            targetEndDate: targetEndDate,
            duration: 25 * 60,
            isPaused: isPaused,
            pausedBy: pausedBy,
            currentRound: 1,
            totalRounds: 4
        )
    }

    private func makeDependencies() -> (
        manager: SessionManager,
        restrictions: MockRestrictionService,
        notifications: MockNotificationService,
        coordinator: RestrictionCoordinator
    ) {
        let restrictions = MockRestrictionService()
        let notifications = MockNotificationService()
        let screenTime = ScreenTimeManager(store: ManagedSettingsStore())
        let coordinator = RestrictionCoordinator(
            screenTimeManager: screenTime,
            restrictionService: restrictions,
            canRestrictEvaluator: { true }
        )
        let manager = SessionManager(
            syncService: MockSessionSyncService(),
            notificationService: notifications,
            restrictionCoordinator: coordinator
        )
        manager.setCurrentUserID("user-b")
        return (manager, restrictions, notifications, coordinator)
    }

    /// Polls until `condition` is true or `timeout` (~ms × 20) elapses, so
    /// tests can wait on the coordinator's serialized `pendingTask` to
    /// finish without sleeping for a fixed worst-case duration.
    private func waitUntil(
        timeout: Int = 30,
        _ condition: @MainActor () async -> Bool
    ) async throws {
        for _ in 0..<timeout {
            if await condition() { return }
            try await Task.sleep(for: .milliseconds(20))
        }
    }

    @Test("remote focus update applies restrictions through the coordinator")
    func remoteFocusAppliesRestrictions() async throws {
        let (manager, restrictions, _, coordinator) = makeDependencies()

        await manager.handleRemoteUpdate(makeSession(state: .focus))
        try await waitUntil { await restrictions.applyCallCount == 1 }

        #expect(await restrictions.applyCallCount == 1)
        // Coordinator's in-memory flag must follow the apply so the
        // active-session chip and any other observers see the new state.
        #expect(coordinator.isRestricting)
    }

    @Test("remote break update lifts restrictions through the coordinator")
    func remoteBreakRemovesRestrictions() async throws {
        let (manager, restrictions, _, coordinator) = makeDependencies()

        await manager.handleRemoteUpdate(makeSession(state: .focus))
        try await waitUntil { coordinator.isRestricting }

        await manager.handleRemoteUpdate(makeSession(state: .shortBreak))
        try await waitUntil { !coordinator.isRestricting }

        #expect(await restrictions.removeCallCount == 1)
        #expect(coordinator.isRestricting == false)
    }

    @Test("remote pause lifts restrictions through the coordinator")
    func remotePauseRemovesRestrictions() async throws {
        let (manager, restrictions, _, coordinator) = makeDependencies()

        await manager.handleRemoteUpdate(makeSession(state: .focus))
        try await waitUntil { coordinator.isRestricting }

        await manager.handleRemoteUpdate(
            makeSession(state: .focus, isPaused: true, pausedBy: "user-a")
        )
        try await waitUntil { !coordinator.isRestricting }

        #expect(await restrictions.removeCallCount == 1)
    }

    @Test("remote resume re-applies restrictions through the coordinator")
    func remoteResumeReappliesRestrictions() async throws {
        let (manager, restrictions, _, coordinator) = makeDependencies()

        await manager.handleRemoteUpdate(
            makeSession(state: .focus, isPaused: true, pausedBy: "user-a")
        )
        // Paused remote update doesn't enqueue a coordinator apply (pause
        // gates `where !isPaused` to false), so no apply yet.
        await manager.handleRemoteUpdate(makeSession(state: .focus))
        try await waitUntil { coordinator.isRestricting }

        #expect(await restrictions.applyCallCount == 1)
    }

    @Test("remote completion lifts restrictions through the coordinator")
    func remoteCompletionRemovesRestrictions() async throws {
        let (manager, restrictions, _, coordinator) = makeDependencies()

        await manager.handleRemoteUpdate(makeSession(state: .focus))
        try await waitUntil { coordinator.isRestricting }

        await manager.handleRemoteUpdate(makeSession(state: .completed))
        try await waitUntil { !coordinator.isRestricting }

        #expect(await restrictions.removeCallCount == 1)
    }

    @Test("remote focus schedules focus-end notification")
    func remoteFocusSchedulesNotification() async {
        let (manager, _, notifications, _) = makeDependencies()

        await manager.handleRemoteUpdate(makeSession(state: .focus))

        let scheduled = await notifications.scheduledNotifications
        #expect(scheduled.count == 1)
        #expect(
            scheduled.last?.message
                == "Focus session complete! Time for a break."
        )
    }

    /// Expired remote focus — target date already past — hits the
    /// `where !hasReachedPhaseEnd()` guard on the apply branch and falls
    /// through to the lift branch. Notifications get cancelled and no
    /// focus-end notification is scheduled; the coordinator's lift is a
    /// safe no-op when the pipeline wasn't already restricting (the old
    /// pre-consolidation path made a defensive remove call here; with the
    /// coordinator as single owner there is nothing to undo because
    /// nothing was ever applied).
    @Test("expired remote focus skips scheduling and leaves coordinator idle")
    func expiredRemoteFocusSkipsScheduling() async throws {
        let (manager, _, notifications, coordinator) = makeDependencies()

        await manager.handleRemoteUpdate(
            makeSession(
                state: .focus,
                targetEndDate: .now.addingTimeInterval(-5)
            )
        )
        try await waitUntil { await notifications.cancelCallCount == 1 }

        let scheduled = await notifications.scheduledNotifications
        let cancelCount = await notifications.cancelCallCount

        #expect(scheduled.isEmpty)
        #expect(cancelCount == 1)
        #expect(coordinator.isRestricting == false)
    }

    @Test("remote break schedules break-end notification")
    func remoteBreakSchedulesNotification() async {
        let (manager, _, notifications, _) = makeDependencies()

        await manager.handleRemoteUpdate(makeSession(state: .focus))
        await manager.handleRemoteUpdate(makeSession(state: .longBreak))

        let scheduled = await notifications.scheduledNotifications
        #expect(scheduled.count == 2)
        #expect(scheduled.last?.message == "Break's over! Ready to focus?")
    }

    @Test("remote pause cancels pending notifications")
    func remotePauseCancelsNotification() async {
        let (manager, _, notifications, _) = makeDependencies()

        await manager.handleRemoteUpdate(makeSession(state: .focus))
        await manager.handleRemoteUpdate(
            makeSession(state: .focus, isPaused: true, pausedBy: "user-a")
        )

        let cancelCount = await notifications.cancelCallCount
        #expect(cancelCount == 1)
    }

    @Test("remote completion cancels pending notifications")
    func remoteCompletionCancelsNotification() async {
        let (manager, _, notifications, _) = makeDependencies()

        await manager.handleRemoteUpdate(makeSession(state: .focus))
        await manager.handleRemoteUpdate(makeSession(state: .completed))

        let cancelCount = await notifications.cancelCallCount
        #expect(cancelCount == 1)
    }

    @Test("duplicate remote state does not re-trigger side effects")
    func duplicateRemoteStateNoOp() async throws {
        let (manager, restrictions, notifications, coordinator) =
            makeDependencies()
        let session = makeSession(state: .focus)

        await manager.handleRemoteUpdate(session)
        try await waitUntil { coordinator.isRestricting }

        await manager.handleRemoteUpdate(session)
        // Give the coordinator a window to enqueue a redundant apply if the
        // dedupe path were broken; if `applyCallCount` ever exceeded 1 this
        // would surface here.
        try await Task.sleep(for: .milliseconds(60))

        let applyCount = await restrictions.applyCallCount
        let scheduledCount = await notifications.scheduledNotifications.count

        #expect(applyCount == 1)
        #expect(scheduledCount == 1)
    }
}

// MARK: - Single-Owner Consolidation

/// Pinned-down regression coverage for the paired Screen Time ownership
/// consolidation.
///
/// Before this work, ``SessionManager`` held a `RestrictionService`,
/// `FocusActivityScheduler`, and called `ShieldSessionContext.writeSession`
/// directly — three independent writers for the same Screen Time pipeline
/// that never updated `RestrictionCoordinator.isRestricting`. The tests
/// below assert that every paired entry point now reaches the coordinator
/// (and only the coordinator) for Screen Time work.
@Suite("Paired Screen Time Single-Owner Consolidation")
@MainActor
struct PairedScreenTimeConsolidationTests {

    private func makeFixture() -> (
        manager: SessionManager,
        restrictions: MockRestrictionService,
        coordinator: RestrictionCoordinator
    ) {
        let restrictions = MockRestrictionService()
        let screenTime = ScreenTimeManager(store: ManagedSettingsStore())
        let coordinator = RestrictionCoordinator(
            screenTimeManager: screenTime,
            restrictionService: restrictions,
            canRestrictEvaluator: { true }
        )
        let manager = SessionManager(
            syncService: MockSessionSyncService(),
            notificationService: MockNotificationService(),
            restrictionCoordinator: coordinator
        )
        manager.setCurrentUserID("user-b")
        return (manager, restrictions, coordinator)
    }

    private func waitUntil(
        timeout: Int = 30,
        _ condition: @MainActor () async -> Bool
    ) async throws {
        for _ in 0..<timeout {
            if await condition() { return }
            try await Task.sleep(for: .milliseconds(20))
        }
    }

    private func makeIncomingFocusRequest() -> StudySession {
        StudySession(
            id: "incoming-1",
            partnerA: "user-a",
            partnerB: "user-b",
            state: .requesting,
            startTime: .now,
            targetEndDate: .now.addingTimeInterval(25 * 60),
            duration: 25 * 60,
            isPaused: false,
            pausedBy: nil,
            currentRound: 1,
            totalRounds: 4
        )
    }

    /// Local Partner-B accept must reach the coordinator's apply path —
    /// before the consolidation, this happened twice (once via
    /// `SessionManager.enforceRestrictions(for:)` direct writes and once
    /// via the view's `onChange(of: session.state)` coordinator call).
    /// Now there is exactly one apply, and the coordinator's flag flips.
    @Test("local acceptSession() drives the coordinator's apply path")
    func localAcceptDrivesCoordinator() async throws {
        let (manager, restrictions, coordinator) = makeFixture()
        await manager.handleRemoteUpdate(makeIncomingFocusRequest())

        await manager.acceptSession()
        try await waitUntil { coordinator.isRestricting }

        #expect(await restrictions.applyCallCount == 1)
        #expect(coordinator.isRestricting)
    }

    /// Remote focus update — the most important regression. Before
    /// consolidation this bypassed the coordinator entirely. After:
    /// `coordinator.isRestricting` flips through the coordinator's path.
    @Test("remote focus update flips coordinator")
    func remoteFocusUpdatesCoordinator() async throws {
        let (manager, _, coordinator) = makeFixture()

        await manager.handleRemoteUpdate(
            StudySession(
                id: "remote-focus",
                partnerA: "user-a",
                partnerB: "user-b",
                state: .focus,
                startTime: .now,
                targetEndDate: .now.addingTimeInterval(25 * 60),
                duration: 25 * 60,
                isPaused: false,
                pausedBy: nil,
                currentRound: 1,
                totalRounds: 4
            )
        )
        try await waitUntil { coordinator.isRestricting }

        #expect(coordinator.isRestricting)
    }

    /// `clearSession()` must drive the coordinator's `forceRemove` path so
    /// the in-memory `isRestricting` flag and the system-side teardown stay
    /// coherent. Before consolidation, `clearSession` removed shields and
    /// stopped monitoring directly while leaving the coordinator's flag
    /// stuck at `true`.
    @Test("clearSession() drives coordinator.forceRemoveRestrictions")
    func clearSessionForcesCoordinatorTeardown() async throws {
        let (manager, restrictions, coordinator) = makeFixture()

        await manager.handleRemoteUpdate(
            StudySession(
                id: "to-clear",
                partnerA: "user-a",
                partnerB: "user-b",
                state: .focus,
                startTime: .now,
                targetEndDate: .now.addingTimeInterval(25 * 60),
                duration: 25 * 60,
                isPaused: false,
                pausedBy: nil,
                currentRound: 1,
                totalRounds: 4
            )
        )
        try await waitUntil { coordinator.isRestricting }
        #expect(coordinator.isRestricting)

        await manager.clearSession()
        try await waitUntil { !coordinator.isRestricting }

        #expect(coordinator.isRestricting == false)
        // forceRemove always calls remove on the underlying service, even
        // when canRestrict has gone false — the assertion is not about
        // count exactly (the lift on transition to no-session may also
        // remove), but about the coordinator flag converging.
        #expect(await restrictions.removeCallCount >= 1)
    }

    /// A subsequent break update lifts the coordinator. This is the path
    /// exercised by remote `(.focus, .shortBreak)` transitions that arrive
    /// while the Partner view is offscreen — without consolidation the
    /// coordinator would have stayed at `isRestricting = true`.
    @Test("remote break after remote focus converges the coordinator flag")
    func remoteBreakConvergesCoordinator() async throws {
        let (manager, _, coordinator) = makeFixture()

        await manager.handleRemoteUpdate(
            StudySession(
                id: "focus-then-break",
                partnerA: "user-a",
                partnerB: "user-b",
                state: .focus,
                startTime: .now,
                targetEndDate: .now.addingTimeInterval(25 * 60),
                duration: 25 * 60,
                isPaused: false,
                pausedBy: nil,
                currentRound: 1,
                totalRounds: 4
            )
        )
        try await waitUntil { coordinator.isRestricting }

        await manager.handleRemoteUpdate(
            StudySession(
                id: "focus-then-break",
                partnerA: "user-a",
                partnerB: "user-b",
                state: .shortBreak,
                startTime: .now,
                targetEndDate: .now.addingTimeInterval(5 * 60),
                duration: 25 * 60,
                isPaused: false,
                pausedBy: nil,
                currentRound: 1,
                totalRounds: 4
            )
        )
        try await waitUntil { !coordinator.isRestricting }

        #expect(coordinator.isRestricting == false)
    }

    /// Without an attached coordinator, paired transitions must not crash
    /// and notification scheduling must still work. This protects test
    /// fixtures elsewhere in the suite that construct ``SessionManager``
    /// without Screen Time wiring.
    @Test("SessionManager without a coordinator still handles paired transitions safely")
    func managerWithoutCoordinatorIsSafe() async {
        let notifications = MockNotificationService()
        let manager = SessionManager(
            syncService: MockSessionSyncService(),
            notificationService: notifications
        )
        manager.setCurrentUserID("user-b")

        await manager.handleRemoteUpdate(
            StudySession(
                id: "no-coord",
                partnerA: "user-a",
                partnerB: "user-b",
                state: .focus,
                startTime: .now,
                targetEndDate: .now.addingTimeInterval(25 * 60),
                duration: 25 * 60,
                isPaused: false,
                pausedBy: nil,
                currentRound: 1,
                totalRounds: 4
            )
        )

        let scheduled = await notifications.scheduledNotifications
        #expect(scheduled.count == 1)
    }
}
