import Foundation
import OSLog
import Observation
@preconcurrency import FirebaseFirestore
@preconcurrency import FirebaseMessaging

/// Stores the device's FCM token in the user's Firestore document so the
/// partner's device can target push notifications to this device.
///
/// The token is refreshed by Firebase periodically and on first launch.
/// ``AppDelegate`` posts ``Notification.Name.didUpdateFCMToken`` whenever
/// a new token arrives; this manager observes that notification and persists
/// the token to `users/{userId}`.
@MainActor
@Observable
final class FCMTokenManager {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.arieljtyson.PomoDuo",
        category: "FCMTokenManager"
    )

    private let database: Firestore
    private var tokenObserverTask: Task<Void, Never>?

    init(database: Firestore = Firestore.firestore()) {
        self.database = database
    }

    /// Begins observing FCM token updates and immediately stores the current
    /// token if one is already available.
    ///
    /// Call this after authentication completes so the token is associated
    /// with the correct user document.
    func startObserving(userID: String) {
        stopObserving()

        // Persist the current token right away if Firebase already minted one.
        Task {
            if let existingToken = Messaging.messaging().fcmToken {
                await persistToken(existingToken, for: userID)
            }
        }

        // Watch for subsequent token refreshes.
        tokenObserverTask = Task { [weak self] in
            let notifications = NotificationCenter.default.notifications(
                named: .didUpdateFCMToken
            )

            for await notification in notifications {
                guard let self, !Task.isCancelled else { return }

                guard let token = notification.userInfo?["token"] as? String else {
                    continue
                }

                await self.persistToken(token, for: userID)
            }
        }
    }

    /// Stops observing token updates.
    ///
    /// Call this when the user signs out.
    func stopObserving() {
        tokenObserverTask?.cancel()
        tokenObserverTask = nil
    }

    // MARK: - Private

    private func persistToken(_ token: String, for userID: String) async {
        let data: [String: Any] = [
            "fcmToken": token,
            "tokenUpdatedAt": FieldValue.serverTimestamp(),
        ]

        do {
            try await database
                .collection("users")
                .document(userID)
                .setData(data, merge: true)

            Self.logger.info("FCM token persisted for user.")
        } catch {
            Self.logger.error(
                "Failed to persist FCM token: \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}
