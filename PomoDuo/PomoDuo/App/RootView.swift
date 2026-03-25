import SwiftUI

/// Root app shell using a bottom tab bar.
///
/// Manages a three-phase launch sequence:
/// 1. **Branded animation** — brief logo + ring animation (~0.8s)
///    masks Firebase initialization.
/// 2. **Skeleton** — structural placeholder matching the real tab layout,
///    shown while anonymous auth resolves.
/// 3. **Ready** — full interactive content with cross-dissolve transition.
///
/// On iOS 26, the native Tab API renders with the system's Liquid Glass look.
struct RootView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(OnboardingManager.self) private var onboardingManager
    @Environment(SessionManager.self) private var sessionManager
    @Environment(SessionObserver.self) private var sessionObserver
    @Environment(FCMTokenManager.self) private var fcmTokenManager
    @Environment(HeartbeatManager.self) private var heartbeatManager
    @Environment(QuickActionManager.self) private var quickActionManager

    @State private var selectedTab = AppTab.timer
    @State private var isShowingOnboarding = false
    @State private var launchPhase = LaunchPhase.branded
    @State private var feedbackCategory: FeedbackCategory?
    @State private var pendingFriendRequestID: String?
    private let pairingService: any PairingService
    private let friendService: any FriendService

    init(
        pairingService: any PairingService = MockPairingService(),
        friendService: any FriendService
    ) {
        self.pairingService = pairingService
        self.friendService = friendService
    }

    var body: some View {
        ZStack {
            // Layer 1: Content (skeleton or real tabs).
            Group {
                switch launchPhase {
                case .branded, .skeleton:
                    SkeletonTabView()
                        .transition(.opacity)

                case .ready:
                    ContentTabView(
                        selectedTab: $selectedTab,
                        isShowingOnboarding: $isShowingOnboarding,
                        pendingFriendRequestID: $pendingFriendRequestID,
                        pairingService: pairingService,
                        friendService: friendService
                    )
                    .environment(onboardingManager)
                    .transition(.opacity)
                }
            }

            // Layer 2: Branded overlay (dismisses itself).
            if launchPhase == .branded {
                LaunchAnimationView {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        launchPhase = .skeleton
                    }
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: launchPhase)
        .task {
            isShowingOnboarding = !onboardingManager.hasCompletedOnboarding
            manageHeartbeat(for: sessionManager.currentSession)
        }
        .task(id: authManager.authState) {
            // Transition to ready once auth resolves past .unknown
            // AND the branded animation has already dismissed.
            guard authManager.authState != .unknown else { return }

            if launchPhase == .skeleton {
                withAnimation(.easeInOut(duration: 0.35)) {
                    launchPhase = .ready
                }
            }
        }
        .onChange(of: launchPhase) { _, newPhase in
            // If auth resolved while the branded animation was still playing,
            // the .skeleton → .ready transition catches it here.
            if newPhase == .skeleton && authManager.authState != .unknown {
                withAnimation(.easeInOut(duration: 0.35)) {
                    launchPhase = .ready
                }
            }
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
        .task(id: quickActionManager.pendingAction) {
            presentFeedbackFromQuickActionIfNeeded()
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
        ) { notification in
            selectedTab = .partner
            if let requestID = notification.userInfo?["friendRequestID"] as? String {
                pendingFriendRequestID = requestID
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: .didTapTimerNotification
            )
        ) { _ in
            selectedTab = .timer
        }
        .onOpenURL { url in
            guard url.scheme == "pomoduo" else { return }
            switch url.host() {
            case "timer":
                selectedTab = .timer
            case "partner":
                selectedTab = .partner
            case "friend-request":
                selectedTab = .partner
                // Extract request ID from path: pomoduo://friend-request/{id}
                let requestID = url.pathComponents.dropFirst().first
                if let requestID, !requestID.isEmpty {
                    pendingFriendRequestID = requestID
                }
            default:
                break
            }
        }
        .sheet(item: $feedbackCategory) { category in
            FeedbackView(category: category)
        }
    }

    // MARK: - Heartbeat Lifecycle

    /// Starts the heartbeat when a paired session is active,
    /// stops it when the session ends or clears.
    private func manageHeartbeat(for session: StudySession?) {
        guard let session,
            let userID = authManager.currentUserID,
            let partnerID = session.partnerID(for: userID),
            session.supportsCountdown,
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

    private func presentFeedbackFromQuickActionIfNeeded() {
        guard let quickAction = quickActionManager.consumePendingAction() else {
            return
        }

        selectedTab = .settings

        switch quickAction {
        case .reportBug:
            feedbackCategory = .bug
        case .suggestFeature:
            feedbackCategory = .feature
        }
    }
}

// MARK: - Launch Phase

private enum LaunchPhase: Equatable {
    /// Brief branded animation is playing.
    case branded
    /// Animation complete; waiting for auth to resolve.
    case skeleton
    /// Auth resolved; full content is visible.
    case ready
}

// MARK: - Content Tabs

/// The real interactive tab bar, shown once auth has resolved.
private struct ContentTabView: View {
    @Binding var selectedTab: AppTab
    @Binding var isShowingOnboarding: Bool
    @Binding var pendingFriendRequestID: String?
    @Environment(OnboardingManager.self) private var onboardingManager

    let pairingService: any PairingService
    let friendService: any FriendService

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
                    PartnerView(
                        pairingService: pairingService,
                        friendService: friendService,
                        pendingFriendRequestID: $pendingFriendRequestID
                    )
                }
            }

            Tab(
                AppTab.history.title,
                systemImage: AppTab.history.systemImage,
                value: .history
            ) {
                NavigationStack {
                    SessionHistoryView(friendService: friendService)
                }
            }

            Tab(
                AppTab.settings.title,
                systemImage: AppTab.settings.systemImage,
                value: .settings
            ) {
                NavigationStack {
                    SettingsView(friendService: friendService)
                }
            }
        }
        .tint(AppColors.lavender)
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
}

// MARK: - Deep-Link Notification

extension Notification.Name {
    /// Posted by ``AppDelegate`` when the user taps a partner-related
    /// push notification, signaling ``RootView`` to switch to the Partner tab.
    static let didTapPartnerNotification = Notification.Name(
        "didTapPartnerNotification"
    )
    static let didTapTimerNotification = Notification.Name(
        "didTapTimerNotification"
    )
}
