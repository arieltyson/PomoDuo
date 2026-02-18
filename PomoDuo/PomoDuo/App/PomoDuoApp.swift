import FirebaseCore
import SwiftData
import SwiftUI

@main
struct PomoDuoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @State private var authManager: AuthManager
    @State private var sessionManager: SessionManager
    @State private var sessionObserver: SessionObserver
    @State private var fcmTokenManager: FCMTokenManager
    @State private var connectionMonitor = ConnectionMonitor()
    @State private var notificationManager = NotificationManager()
    @State private var liveActivityManager = LiveActivityManager()
    @State private var focusIntentState = FocusIntentState.shared
    @State private var screenTimeManager: ScreenTimeManager
    @State private var restrictionCoordinator: RestrictionCoordinator
    @State private var onboardingManager = OnboardingManager()
    @State private var appearanceManager = AppearanceManager()
    private let pairingService: any PairingService

    init() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        let authService = FirebaseAuthService()
        let pairingService = FirebasePairingService()
        let syncService = FirebaseSessionSyncService()
        _fcmTokenManager = State(initialValue: FCMTokenManager())

        _authManager = State(
            initialValue: AuthManager(authService: authService)
        )
        self.pairingService = pairingService

        let screenTimeManager = ScreenTimeManager()
        _screenTimeManager = State(initialValue: screenTimeManager)
        _restrictionCoordinator = State(
            initialValue: RestrictionCoordinator(
                screenTimeManager: screenTimeManager
            )
        )

        // The restriction and notification services are shared between
        // SessionManager (for paired sessions) and the solo timer flow.
        // Both paths target the same ManagedSettingsStore and notification
        // center, so the last writer wins — which is correct because solo
        // and paired sessions are mutually exclusive.
        let restrictionService = ManagedSettingsRestrictionService(
            screenTimeManager: screenTimeManager
        )
        let notificationService = LocalNotificationService()

        let sessionManager = SessionManager(
            syncService: syncService,
            restrictionService: restrictionService,
            notificationService: notificationService
        )
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
                .environment(connectionMonitor)
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
