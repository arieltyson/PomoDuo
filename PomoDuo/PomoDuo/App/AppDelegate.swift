import OSLog
import UIKit
import FirebaseMessaging
import UserNotifications

@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.arieljtyson.PomoDuo",
        category: "PushNotifications"
    )

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self

        // APNs registration is required for Firebase to mint an FCM token.
        application.registerForRemoteNotifications()

        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Self.logger.warning(
            "APNs registration failed: \(error.localizedDescription, privacy: .public)"
        )
    }
}

extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else {
            return
        }

        Self.logger.notice("Received FCM registration token.")
        NotificationCenter.default.post(
            name: .didUpdateFCMToken,
            object: nil,
            userInfo: ["token": fcmToken]
        )
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        Self.logger.debug(
            "Notification interaction received with action \(response.actionIdentifier, privacy: .public)"
        )
    }
}

extension Notification.Name {
    static let didUpdateFCMToken = Notification.Name("didUpdateFCMToken")
}
