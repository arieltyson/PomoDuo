import SwiftUI
import SwiftData
import FirebaseCore

@main
struct PomoDuoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @State private var authManager: AuthManager
    @State private var sessionManager: SessionManager
    @State private var sessionObserver: SessionObserver
    @State private var fcmTokenManager = FCMTokenManager()
    @State private var notificationManager = NotificationManager()
    @State private var liveActivityManager = LiveActivityManager()
    @State private var focusIntentState = FocusIntentState.shared
    @State private var screenTimeManager: ScreenTimeManager
    @State private var restrictionCoordinator: RestrictionCoordinator
    @State private var onboardingManager = OnboardingManager()
    @State private var appearanceManager = AppearanceManager()
    private let pairingService: any PairingService

    init() {
        FirebaseApp.configure()

        let authService = FirebaseAuthService()
        let pairingService = FirebasePairingService()
        let syncService = FirebaseSessionSyncService()

        _authManager = State(
            initialValue: AuthManager(authService: authService)
        )
        self.pairingService = pairingService

        let screenTimeManager = ScreenTimeManager()
        _screenTimeManager = State(initialValue: screenTimeManager)
        _restrictionCoordinator = State(
            initialValue: RestrictionCoordinator(screenTimeManager: screenTimeManager)
        )

        let sessionManager = SessionManager(syncService: syncService)
        _sessionManager = State(initialValue: sessionManager)
        _sessionObserver = State(
            initialValue: SessionObserver(
                syncService: syncService,
                sessionManager: sessionManager
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView(pairingService: pairingService)
                .environment(authManager)
                .environment(sessionManager)
                .environment(sessionObserver)
                .environment(fcmTokenManager)
                .environment(notificationManager)
                .environment(liveActivityManager)
                .environment(focusIntentState)
                .environment(screenTimeManager)
                .environment(restrictionCoordinator)
                .environment(onboardingManager)
                .environment(appearanceManager)
                .preferredColorScheme(appearanceManager.preferredColorScheme)
                .task {
                    await authManager.start()
                    await notificationManager.refreshAuthorizationStatus()
                    screenTimeManager.refreshAuthorizationStatus()
                }
        }
        .modelContainer(for: StorageConfiguration.modelTypes)
    }
}
