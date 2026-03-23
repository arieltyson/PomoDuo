import Foundation
import OSLog
import UserNotifications

/// Notification-specific operations used by the UI notification manager.
protocol LocalNotificationManaging: NotificationService {
    /// Requests local notification permission from the user.
    func requestAuthorization() async -> Bool

    /// Returns the current local notification authorization status.
    func authorizationStatus() async -> UNAuthorizationStatus
}

/// Combined local + remote notification service.
///
/// Local operations (timer-end scheduling, cancellation) are handled
/// directly via `UNUserNotificationCenter`.
///
/// Remote operations (session request, pause, resume) delegate to
/// ``PushNotificationSender``, which writes push notification requests
/// to Firestore for a Cloud Function to deliver via FCM.
///
/// If no `PushNotificationSender` is provided (e.g., in tests or
/// before Firebase is configured), remote methods are graceful no-ops.
actor LocalNotificationService: LocalNotificationManaging {
    nonisolated private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.arieljtyson.PomoDuo",
        category: "LocalNotificationService"
    )

    nonisolated private static let timerEndCategoryID = "TIMER_END"
    nonisolated private static let timerEndRequestID = "pomoduo.timer.end"

    private let center = UNUserNotificationCenter.current()
    private let pushSender: PushNotificationSender?

    init(pushSender: PushNotificationSender? = nil) {
        self.pushSender = pushSender
    }

    // MARK: - Authorization

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

    // MARK: - Remote Push (via Firestore -> Cloud Function -> FCM)

    func sendSessionRequest(to partnerID: String, from senderName: String)
        async throws
    {
        guard let pushSender else {
            Self.logger.debug("Push sender unavailable - skipping session request push.")
            return
        }

        try await pushSender.sendPush(
            to: partnerID,
            title: "Focus Session Request",
            body: "\(senderName) wants to focus with you!",
            category: .sessionRequest,
            payload: ["action": "session_request"]
        )
    }

    func sendPauseNotification(to partnerID: String, pausedBy name: String)
        async throws
    {
        guard let pushSender else {
            Self.logger.debug("Push sender unavailable - skipping pause push.")
            return
        }

        try await pushSender.sendPush(
            to: partnerID,
            title: "Session Paused",
            body: "\(name) paused the session.",
            category: .sessionPaused,
            payload: ["action": "session_paused"]
        )
    }

    func sendResumeNotification(to partnerID: String) async throws {
        guard let pushSender else {
            Self.logger.debug("Push sender unavailable - skipping resume push.")
            return
        }

        try await pushSender.sendPush(
            to: partnerID,
            title: "Session Resumed",
            body: "Your focus session is back on!",
            category: .sessionResumed,
            payload: ["action": "session_resumed"]
        )
    }

    func sendSessionEndedNotification(to partnerID: String, endedBy name: String)
        async throws
    {
        guard let pushSender else {
            Self.logger.debug("Push sender unavailable - skipping session ended push.")
            return
        }

        try await pushSender.sendPush(
            to: partnerID,
            title: "Session Ended",
            body: "\(name) ended the study session.",
            category: .sessionEnded,
            payload: ["action": "session_ended"]
        )
    }

    // MARK: - Local Notifications

    func scheduleTimerEndNotification(at date: Date, message: String)
        async throws
    {
        center.removePendingNotificationRequests(withIdentifiers: [
            Self.timerEndRequestID
        ])

        let interval = date.timeIntervalSinceNow
        guard interval > 0 else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "PomoDuo"
        content.body = message
        content.sound = .default
        content.categoryIdentifier = Self.timerEndCategoryID
        content.interruptionLevel = .timeSensitive

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, interval),
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
