import Foundation
import Observation
import UserNotifications

/// Main-actor observable coordinator for local notification authorization
/// and timer-end scheduling behavior.
@MainActor
@Observable
final class NotificationManager {
    /// Whether local notifications are currently authorized.
    private(set) var isAuthorized = false

    /// Whether authorization has been checked in this app launch.
    private(set) var hasCheckedAuthorization = false

    private let service: any LocalNotificationManaging

    init(service: any LocalNotificationManaging = LocalNotificationService()) {
        self.service = service
    }

    /// Reads the current system authorization status without prompting.
    func refreshAuthorizationStatus() async {
        let status = await service.authorizationStatus()
        isAuthorized =
            status == .authorized || status == .provisional
            || status == .ephemeral
        hasCheckedAuthorization = true
    }

    /// Requests notification authorization from the user.
    func requestPermission() async {
        let granted = await service.requestAuthorization()
        isAuthorized = granted
        hasCheckedAuthorization = true
    }

    /// Schedules a local notification for timer completion.
    func scheduleTimerEnd(at endDate: Date, message: String) async {
        guard isAuthorized else { return }

        do {
            try await service.scheduleTimerEndNotification(
                at: endDate,
                message: message
            )
        } catch {
            // Scheduling is best-effort and should not disrupt timer flow.
        }
    }

    /// Cancels any pending timer completion notification.
    func cancelTimerEnd() async {
        do {
            try await service.cancelPendingNotifications()
        } catch {
            // Cancellation failures are non-fatal.
        }
    }
}
