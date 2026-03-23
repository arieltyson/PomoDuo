import Foundation
import OSLog
@preconcurrency import FirebaseFirestore

/// Writes push notification requests to a Firestore collection
/// that a Cloud Function watches and delivers via FCM.
///
/// This is the client-side half of the push notification pipeline.
/// The server-side half is a Firebase Cloud Function that:
/// 1. Watches `pushNotifications/{docId}` for new documents
/// 2. Reads the target user's FCM token from `users/{userId}`
/// 3. Sends the push via FCM Admin SDK
/// 4. Deletes the processed document
///
/// If the Cloud Function isn't deployed yet, the documents simply
/// accumulate harmlessly. The real-time Firestore listener handles
/// the common case (both apps running); push is the fallback for
/// when the partner's app is suspended or terminated.
actor PushNotificationSender {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.arieljtyson.PomoDuo",
        category: "PushNotificationSender"
    )

    private enum Collections {
        static let pushNotifications = "pushNotifications"
    }

    private enum Fields {
        static let targetUserID = "targetUserID"
        static let title = "title"
        static let body = "body"
        static let category = "category"
        static let data = "data"
        static let createdAt = "createdAt"
        static let processed = "processed"
    }

    /// Categories that the Cloud Function can use to set the notification's
    /// `category` identifier for actionable notifications.
    enum PushCategory: String, Sendable {
        case sessionRequest = "SESSION_REQUEST"
        case sessionPaused = "SESSION_PAUSED"
        case sessionResumed = "SESSION_RESUMED"
        case sessionEnded = "SESSION_ENDED"
        case friendRequest = "FRIEND_REQUEST"
        case friendRequestAccepted = "FRIEND_ACCEPTED"
    }

    private let database: Firestore

    init(database: Firestore = Firestore.firestore()) {
        self.database = database
    }

    /// Writes a push notification request to Firestore.
    ///
    /// The Cloud Function picks this up, resolves the target's FCM token,
    /// sends the push, and deletes the document.
    ///
    /// - Parameters:
    ///   - userID: The target user's Firestore UID.
    ///   - title: The notification title.
    ///   - body: The notification body.
    ///   - category: The push category for actionable handling.
    ///   - payload: Additional key-value data included in the push payload.
    func sendPush(
        to userID: String,
        title: String,
        body: String,
        category: PushCategory,
        payload: [String: String] = [:]
    ) async throws {
        let document: [String: Any] = [
            Fields.targetUserID: userID,
            Fields.title: title,
            Fields.body: body,
            Fields.category: category.rawValue,
            Fields.data: payload,
            Fields.createdAt: FieldValue.serverTimestamp(),
            Fields.processed: false,
        ]

        try await database
            .collection(Collections.pushNotifications)
            .addDocument(data: document)

        Self.logger.info(
            "Push notification request queued for category \(category.rawValue, privacy: .public)."
        )
    }
}
