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
            }
        }
        .onChange(of: onboardingManager.hasCompletedOnboarding) {
            _,
            hasCompleted in
            isShowingOnboarding = !hasCompleted
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
}
