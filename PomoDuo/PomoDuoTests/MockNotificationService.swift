import Foundation
@testable import PomoDuo

/// Test-friendly notification service with call tracking.
actor MockNotificationService: NotificationService {
    private(set) var sessionRequestsSent: [(partnerID: String, senderName: String)] = []
    private(set) var pauseNotificationsSent: [(partnerID: String, pausedBy: String)] = []
    private(set) var resumeNotificationsSent: [String] = []
    private(set) var scheduledNotifications: [(date: Date, message: String)] = []
    private(set) var cancelCallCount = 0

    func sendSessionRequest(to partnerID: String, from senderName: String) async throws {
        sessionRequestsSent.append((partnerID: partnerID, senderName: senderName))
    }

    func sendPauseNotification(to partnerID: String, pausedBy name: String) async throws {
        pauseNotificationsSent.append((partnerID: partnerID, pausedBy: name))
    }

    func sendResumeNotification(to partnerID: String) async throws {
        resumeNotificationsSent.append(partnerID)
    }

    func scheduleTimerEndNotification(at date: Date, message: String) async throws {
        scheduledNotifications.append((date: date, message: message))
    }

    func cancelPendingNotifications() async throws {
        cancelCallCount += 1
    }

    func reset() {
        sessionRequestsSent.removeAll()
        pauseNotificationsSent.removeAll()
        resumeNotificationsSent.removeAll()
        scheduledNotifications.removeAll()
        cancelCallCount = 0
    }
}
