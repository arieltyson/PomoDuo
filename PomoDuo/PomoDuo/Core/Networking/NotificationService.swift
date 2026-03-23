import Foundation

/// Abstracts notification delivery so the session logic
/// does not depend on UNUserNotificationCenter or FCM directly.
protocol NotificationService: Sendable {
    /// Sends a session request notification to the partner.
    func sendSessionRequest(to partnerID: String, from senderName: String)
        async throws

    /// Sends a notification that the partner paused the session.
    func sendPauseNotification(to partnerID: String, pausedBy name: String)
        async throws

    /// Sends a notification that the session was resumed.
    func sendResumeNotification(to partnerID: String) async throws

    /// Sends a notification that the session was ended by the partner.
    func sendSessionEndedNotification(to partnerID: String, endedBy name: String)
        async throws

    /// Schedules a local notification for when a focus or break period ends.
    func scheduleTimerEndNotification(at date: Date, message: String)
        async throws

    /// Cancels all pending local notifications.
    func cancelPendingNotifications() async throws
}
