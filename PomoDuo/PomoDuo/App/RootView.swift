import SwiftUI

/// Root app shell using a bottom tab bar.
///
/// On iOS 26, the native Tab API renders with the system's Liquid Glass look.
struct RootView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(OnboardingManager.self) private var onboardingManager
    @Environment(SessionManager.self) private var sessionManager
    @Environment(SessionObserver.self) private var sessionObserver
    @Environment(FCMTokenManager.self) private var fcmTokenManager
    @Environment(HeartbeatManager.self) private var heartbeatManager

    @State private var selectedTab = AppTab.timer
    @State private var isShowingOnboarding = false
    private let pairingService: any PairingService

    init(pairingService: any PairingService = MockPairingService()) {
        self.pairingService = pairingService
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(
                AppTab.timer.title,
                systemImage: AppTab.timer.systemImage,
                value: .timer
            ) {
                NavigationStack {
                    TimerView()
                }
            }

            Tab(
                AppTab.partner.title,
                systemImage: AppTab.partner.systemImage,
                value: .partner
            ) {
                NavigationStack {
                    PartnerView(pairingService: pairingService)
                }
            }

            Tab(
                AppTab.history.title,
                systemImage: AppTab.history.systemImage,
                value: .history
            ) {
                NavigationStack {
                    SessionHistoryView()
                }
            }

            Tab(
                AppTab.settings.title,
                systemImage: AppTab.settings.systemImage,
                value: .settings
            ) {
                NavigationStack {
                    SettingsView()
                }
            }
        }
        .tint(AppColors.lavender)
        .task {
            isShowingOnboarding = !onboardingManager.hasCompletedOnboarding
            manageHeartbeat(for: sessionManager.currentSession)
        }
        .task(id: authManager.currentUserID) {
            let userID = authManager.currentUserID
            sessionManager.setCurrentUserID(userID)

            if let userID {
                sessionObserver.startObserving(userID: userID)
                fcmTokenManager.startObserving(userID: userID)
            } else {
                sessionObserver.stopObserving()
                fcmTokenManager.stopObserving()
                heartbeatManager.stopBeating()
            }
        }
        .onChange(of: sessionManager.currentSession) { _, session in
            manageHeartbeat(for: session)
        }
        .onChange(of: onboardingManager.hasCompletedOnboarding) {
            _,
            hasCompleted in
            isShowingOnboarding = !hasCompleted
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: .didTapPartnerNotification
            )
        ) { _ in
            selectedTab = .partner
        }
        .fullScreenCover(isPresented: $isShowingOnboarding) {
            OnboardingView(
                onComplete: {
                    onboardingManager.completeOnboarding()
                },
                onOpenSettings: {
                    selectedTab = .settings
                }
            )
        }
    }

    // MARK: - Heartbeat Lifecycle

    /// Starts the heartbeat when a paired session is active,
    /// stops it when the session ends or clears.
    private func manageHeartbeat(for session: StudySession?) {
        guard let session,
            let userID = authManager.currentUserID,
            let partnerID = session.partnerID(for: userID),
            session.state != .idle,
            session.state != .completed
        else {
            heartbeatManager.stopBeating()
            return
        }

        heartbeatManager.startBeating(
            sessionID: session.id,
            userID: userID,
            partnerID: partnerID,
            onPartnerStale: { [sessionManager] in
                await sessionManager.completeSession()
            }
        )
    }
}

// MARK: - Deep-Link Notification

extension Notification.Name {
    /// Posted by ``AppDelegate`` when the user taps a partner-related
    /// push notification, signaling ``RootView`` to switch to the Partner tab.
    static let didTapPartnerNotification = Notification.Name(
        "didTapPartnerNotification"
    )
}
