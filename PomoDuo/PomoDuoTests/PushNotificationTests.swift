import Foundation
import Testing

@testable import PomoDuo

@MainActor
@Suite("Push Notification Delivery")
struct PushNotificationTests {

    // MARK: - LocalNotificationService without push sender

    @Test("Remote methods are no-ops when push sender is nil")
    func remoteMethodsAreNoOpsWithoutSender() async throws {
        let service = LocalNotificationService(pushSender: nil)

        // These should not throw - they're graceful no-ops.
        try await service.sendSessionRequest(
            to: "partner-id",
            from: "Test User"
        )
        try await service.sendPauseNotification(
            to: "partner-id",
            pausedBy: "Test User"
        )
        try await service.sendResumeNotification(to: "partner-id")
    }

    // MARK: - PushNotificationSender category values

    @Test("Push categories have stable raw values for Cloud Function matching")
    func categoryRawValues() {
        #expect(
            PushNotificationSender.PushCategory.sessionRequest.rawValue
                == "SESSION_REQUEST"
        )
        #expect(
            PushNotificationSender.PushCategory.sessionPaused.rawValue
                == "SESSION_PAUSED"
        )
        #expect(
            PushNotificationSender.PushCategory.sessionResumed.rawValue
                == "SESSION_RESUMED"
        )
    }

    // MARK: - Deep-link notification name

    @Test("Partner notification name is stable")
    func partnerNotificationNameIsStable() {
        let name = Notification.Name.didTapPartnerNotification
        #expect(name.rawValue == "didTapPartnerNotification")
    }

    @Test("FCM token notification name is stable")
    func fcmTokenNotificationNameIsStable() {
        let name = Notification.Name.didUpdateFCMToken
        #expect(name.rawValue == "didUpdateFCMToken")
    }
}
