import Foundation
import Testing
@testable import PomoDuo

@Suite("SessionManager Remote Sync Side Effects")
@MainActor
struct SessionManagerRemoteSyncTests {
    private func makeSession(
        id: String = "session-1",
        state: SessionState = .idle,
        isPaused: Bool = false,
        pausedBy: String? = nil
    ) -> StudySession {
        StudySession(
            id: id,
            partnerA: "user-a",
            partnerB: "user-b",
            state: state,
            startTime: .now,
            targetEndDate: .now.addingTimeInterval(25 * 60),
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
        notifications: MockNotificationService
    ) {
        let restrictions = MockRestrictionService()
        let notifications = MockNotificationService()
        let manager = SessionManager(
            syncService: MockSessionSyncService(),
            restrictionService: restrictions,
            notificationService: notifications
        )
        manager.setCurrentUserID("user-b")
        return (manager, restrictions, notifications)
    }

    @Test("remote focus update applies restrictions")
    func remoteFocusAppliesRestrictions() async {
        let (manager, restrictions, _) = makeDependencies()

        await manager.handleRemoteUpdate(makeSession(state: .focus))

        let applied = await restrictions.applyCallCount
        #expect(applied == 1)
    }

    @Test("remote break update removes restrictions")
    func remoteBreakRemovesRestrictions() async {
        let (manager, restrictions, _) = makeDependencies()

        await manager.handleRemoteUpdate(makeSession(state: .focus))
        await manager.handleRemoteUpdate(makeSession(state: .shortBreak))

        let removed = await restrictions.removeCallCount
        #expect(removed == 1)
    }

    @Test("remote pause removes restrictions")
    func remotePauseRemovesRestrictions() async {
        let (manager, restrictions, _) = makeDependencies()

        await manager.handleRemoteUpdate(makeSession(state: .focus))
        await manager.handleRemoteUpdate(
            makeSession(state: .focus, isPaused: true, pausedBy: "user-a")
        )

        let removed = await restrictions.removeCallCount
        #expect(removed == 1)
    }

    @Test("remote resume re-applies restrictions")
    func remoteResumeReappliesRestrictions() async {
        let (manager, restrictions, _) = makeDependencies()

        await manager.handleRemoteUpdate(
            makeSession(state: .focus, isPaused: true, pausedBy: "user-a")
        )
        await manager.handleRemoteUpdate(makeSession(state: .focus))

        let applied = await restrictions.applyCallCount
        #expect(applied == 1)
    }

    @Test("remote completion removes restrictions")
    func remoteCompletionRemovesRestrictions() async {
        let (manager, restrictions, _) = makeDependencies()

        await manager.handleRemoteUpdate(makeSession(state: .focus))
        await manager.handleRemoteUpdate(makeSession(state: .completed))

        let removed = await restrictions.removeCallCount
        #expect(removed == 1)
    }

    @Test("remote focus schedules focus-end notification")
    func remoteFocusSchedulesNotification() async {
        let (manager, _, notifications) = makeDependencies()

        await manager.handleRemoteUpdate(makeSession(state: .focus))

        let scheduled = await notifications.scheduledNotifications
        #expect(scheduled.count == 1)
        #expect(
            scheduled.last?.message
                == "Focus session complete! Time for a break."
        )
    }

    @Test("remote break schedules break-end notification")
    func remoteBreakSchedulesNotification() async {
        let (manager, _, notifications) = makeDependencies()

        await manager.handleRemoteUpdate(makeSession(state: .focus))
        await manager.handleRemoteUpdate(makeSession(state: .longBreak))

        let scheduled = await notifications.scheduledNotifications
        #expect(scheduled.count == 2)
        #expect(scheduled.last?.message == "Break's over! Ready to focus?")
    }

    @Test("remote pause cancels pending notifications")
    func remotePauseCancelsNotification() async {
        let (manager, _, notifications) = makeDependencies()

        await manager.handleRemoteUpdate(makeSession(state: .focus))
        await manager.handleRemoteUpdate(
            makeSession(state: .focus, isPaused: true, pausedBy: "user-a")
        )

        let cancelCount = await notifications.cancelCallCount
        #expect(cancelCount == 1)
    }

    @Test("remote completion cancels pending notifications")
    func remoteCompletionCancelsNotification() async {
        let (manager, _, notifications) = makeDependencies()

        await manager.handleRemoteUpdate(makeSession(state: .focus))
        await manager.handleRemoteUpdate(makeSession(state: .completed))

        let cancelCount = await notifications.cancelCallCount
        #expect(cancelCount == 1)
    }

    @Test("duplicate remote state does not re-trigger side effects")
    func duplicateRemoteStateNoOp() async {
        let (manager, restrictions, notifications) = makeDependencies()
        let session = makeSession(state: .focus)

        await manager.handleRemoteUpdate(session)
        await manager.handleRemoteUpdate(session)

        let applyCount = await restrictions.applyCallCount
        let scheduledCount = await notifications.scheduledNotifications.count

        #expect(applyCount == 1)
        #expect(scheduledCount == 1)
    }
}
