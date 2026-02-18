import FirebaseCore
import FirebaseMessaging
import OSLog
import UIKit
import UserNotifications

@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.arieljtyson.PomoDuo",
        category: "PushNotifications"
    )

    /// Push categories/actions that should navigate the user to the Partner tab.
    private static let partnerCategories: Set<String> = [
        "SESSION_REQUEST",
        "SESSION_PAUSED",
        "SESSION_RESUMED",
        "session_request",
        "session_paused",
        "session_resumed",
    ]

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication
            .LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

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
    func messaging(
        _ messaging: Messaging,
        didReceiveRegistrationToken fcmToken: String?
    ) {
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
    /// Presents the notification banner even when the app is in the foreground.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    /// Handles user taps on notification banners.
    ///
    /// If the notification belongs to a partner-related category (session
    /// request, pause, resume), posts ``Notification.Name.didTapPartnerNotification``
    /// so ``RootView`` can switch to the Partner tab.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo

        // Check the payload category/action first, then fall back to APNs category.
        let category: String? =
            userInfo["category"] as? String
            ?? userInfo["action"] as? String
            ?? (userInfo["data"] as? [String: Any])?["action"] as? String
            ?? response.notification.request.content.categoryIdentifier
                .nilIfEmpty

        Self.logger.debug(
            "Notification tapped - category: \(category ?? "none", privacy: .public)"
        )

        if let category, Self.partnerCategories.contains(category) {
            NotificationCenter.default.post(
                name: .didTapPartnerNotification,
                object: nil
            )
        }
    }
}

extension Notification.Name {
    static let didUpdateFCMToken = Notification.Name("didUpdateFCMToken")
}

// MARK: - Helpers

private extension String {
    /// Returns `nil` if the string is empty, otherwise returns `self`.
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
