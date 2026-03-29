import Foundation
import Observation
import OSLog
import UserNotifications

/// Observes incoming friend requests via the Firestore real-time listener
/// and posts local notifications for new requests.
///
/// This supplements the push notification path (Firestore -> Cloud Function -> FCM)
/// by ensuring the user sees a notification whenever the Firestore listener fires,
/// even if the Cloud Function is unavailable or delayed.
@MainActor
@Observable
final class FriendRequestNotificationObserver {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.arieljtyson.PomoDuo",
        category: "FriendRequestNotifications"
    )

    private static let categoryID = "FRIEND_REQUEST"
    private static let requestIDPrefix = "pomoduo.friend.request."

    private let friendService: any FriendService

    private var observationTask: Task<Void, Never>?
    private var knownRequestIDs: Set<String> = []
    private var hasReceivedInitialSnapshot = false

    init(friendService: any FriendService) {
        self.friendService = friendService
    }

    /// Begins listening for incoming friend requests.
    ///
    /// The first snapshot is treated as existing state and does not
    /// trigger notifications. Only requests that appear in subsequent
    /// snapshots are considered new.
    func startObserving() {
        stopObserving()
        hasReceivedInitialSnapshot = false
        knownRequestIDs = []

        observationTask = Task { [weak self, friendService] in
            for await requests in friendService.incomingRequestsStream() {
                guard !Task.isCancelled, let self else { return }

                let currentIDs = Set(requests.map(\.id))

                if self.hasReceivedInitialSnapshot {
                    let newRequests = requests.filter {
                        !self.knownRequestIDs.contains($0.id)
                    }
                    for request in newRequests {
                        await self.scheduleLocalNotification(for: request)
                    }
                }

                self.knownRequestIDs = currentIDs
                self.hasReceivedInitialSnapshot = true
            }
        }
    }

    func stopObserving() {
        observationTask?.cancel()
        observationTask = nil
    }

    // MARK: - Local Notification

    private func scheduleLocalNotification(
        for request: FriendRequest
    ) async {
        let content = UNMutableNotificationContent()
        content.title = "Friend Request"
        content.body = "\(request.fromDisplayName) wants to be study friends!"
        content.sound = .default
        content.categoryIdentifier = Self.categoryID
        content.userInfo = [
            "action": "friend_request",
            "friendRequestID": request.id,
        ]

        let notificationRequest = UNNotificationRequest(
            identifier: "\(Self.requestIDPrefix)\(request.id)",
            content: content,
            trigger: nil
        )

        do {
            try await UNUserNotificationCenter.current().add(notificationRequest)
            Self.logger.info(
                "Scheduled local notification for friend request from \(request.fromDisplayName, privacy: .private)"
            )
        } catch {
            Self.logger.error(
                "Failed to schedule friend request notification: \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}
