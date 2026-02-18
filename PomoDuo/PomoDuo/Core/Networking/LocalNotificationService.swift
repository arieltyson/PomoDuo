import Foundation
import UserNotifications

/// Notification-specific operations used by the UI notification manager.
protocol LocalNotificationManaging: NotificationService {
    /// Requests local notification permission from the user.
    func requestAuthorization() async -> Bool

    /// Returns the current local notification authorization status.
    func authorizationStatus() async -> UNAuthorizationStatus
}

/// Local notification implementation backed by `UNUserNotificationCenter`.
///
/// Remote push methods are intentionally no-ops for now and will be
/// implemented when the Firebase sync layer is added.
actor LocalNotificationService: LocalNotificationManaging {
    nonisolated private static let timerEndCategoryID = "TIMER_END"
    nonisolated private static let timerEndRequestID = "pomoduo.timer.end"

    private let center = UNUserNotificationCenter.current()

    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [
                .alert, .sound, .badge,
            ])
        } catch {
            return false
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func sendSessionRequest(to partnerID: String, from senderName: String)
        async throws
    {}

    func sendPauseNotification(to partnerID: String, pausedBy name: String)
        async throws
    {}

    func sendResumeNotification(to partnerID: String) async throws {}

    func scheduleTimerEndNotification(at date: Date, message: String)
        async throws
    {
        center.removePendingNotificationRequests(withIdentifiers: [
            Self.timerEndRequestID
        ])

        let content = UNMutableNotificationContent()
        content.title = "PomoDuo"
        content.body = message
        content.sound = .default
        content.categoryIdentifier = Self.timerEndCategoryID
        content.interruptionLevel = .timeSensitive

        let interval = max(1, date.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: interval,
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: Self.timerEndRequestID,
            content: content,
            trigger: trigger
        )

        try await center.add(request)
    }

    func cancelPendingNotifications() async throws {
        center.removePendingNotificationRequests(withIdentifiers: [
            Self.timerEndRequestID
        ])
    }
}
