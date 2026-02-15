//
//  NotificationTests.swift
//  PomoDuoTests
//
//  Created by Codex on 2/15/26.
//

import Foundation
import Testing
import UserNotifications
@testable import PomoDuo

@MainActor
private final class MockLocalNotificationService: LocalNotificationManaging {
    private var authorizationStatusValue: UNAuthorizationStatus = .notDetermined
    private var requestResult = false
    private var scheduledRequests: [(date: Date, message: String)] = []
    private var cancellationCountValue = 0

    func setAuthorizationStatus(_ status: UNAuthorizationStatus) {
        authorizationStatusValue = status
    }

    func setRequestResult(_ result: Bool) {
        requestResult = result
    }

    func scheduledCount() -> Int {
        scheduledRequests.count
    }

    func lastScheduledMessage() -> String? {
        scheduledRequests.last?.message
    }

    func cancellationCount() -> Int {
        cancellationCountValue
    }

    func requestAuthorization() async -> Bool {
        requestResult
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        authorizationStatusValue
    }

    func sendSessionRequest(to partnerID: String, from senderName: String) async throws {}

    func sendPauseNotification(to partnerID: String, pausedBy name: String) async throws {}

    func sendResumeNotification(to partnerID: String) async throws {}

    func scheduleTimerEndNotification(at date: Date, message: String) async throws {
        scheduledRequests.append((date: date, message: message))
    }

    func cancelPendingNotifications() async throws {
        cancellationCountValue += 1
    }
}

@MainActor
struct NotificationManagerTests {
    @Test func refreshAuthorizationStatusUpdatesObservableState() async {
        let service = MockLocalNotificationService()
        service.setAuthorizationStatus(.authorized)

        let manager = NotificationManager(service: service)
        await manager.refreshAuthorizationStatus()

        #expect(manager.hasCheckedAuthorization)
        #expect(manager.isAuthorized)
    }

    @Test func requestPermissionUsesServiceResult() async {
        let service = MockLocalNotificationService()
        service.setRequestResult(true)

        let manager = NotificationManager(service: service)
        await manager.requestPermission()

        #expect(manager.hasCheckedAuthorization)
        #expect(manager.isAuthorized)
    }

    @Test func scheduleRequiresAuthorization() async {
        let service = MockLocalNotificationService()
        let manager = NotificationManager(service: service)

        await manager.scheduleTimerEnd(
            at: .now.addingTimeInterval(1500),
            message: "Focus session complete!"
        )
        #expect(service.scheduledCount() == 0)

        service.setRequestResult(true)
        await manager.requestPermission()
        await manager.scheduleTimerEnd(
            at: .now.addingTimeInterval(300),
            message: "Break over!"
        )

        #expect(service.scheduledCount() == 1)
        #expect(service.lastScheduledMessage() == "Break over!")
    }

    @Test func cancelForwardsToService() async {
        let service = MockLocalNotificationService()
        let manager = NotificationManager(service: service)

        await manager.cancelTimerEnd()
        await manager.cancelTimerEnd()

        #expect(service.cancellationCount() == 2)
    }
}
