import FirebaseCore
import ManagedSettings
import SwiftData
import SwiftUI

@main
struct PomoDuoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @State private var authManager: AuthManager
    @State private var sessionManager: SessionManager
    @State private var sessionObserver: SessionObserver
    @State private var fcmTokenManager: FCMTokenManager
    @State private var heartbeatManager: HeartbeatManager
    @State private var connectionMonitor = ConnectionMonitor()
    @State private var notificationManager = NotificationManager()
    @State private var liveActivityManager = LiveActivityManager()
    @State private var quickActionManager = QuickActionManager()
    @State private var focusIntentState = FocusIntentState.shared
    @State private var screenTimeManager: ScreenTimeManager
    @State private var restrictionCoordinator: RestrictionCoordinator
    @State private var powerStateMonitor = PowerStateMonitor()
    @State private var onboardingManager = OnboardingManager()
    @State private var appearanceManager = AppearanceManager()
    @State private var focusStatsReporter: FocusStatsReporter
    private let pairingService: any PairingService
    private let friendService: any FriendService

    init() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        let authService = FirebaseAuthService()
        let pairingService = FirebasePairingService()
        let syncService = FirebaseSessionSyncService()
        let pushSender = PushNotificationSender()
        let friendService = FirebaseFriendService(pushSender: pushSender)
        _fcmTokenManager = State(initialValue: FCMTokenManager())
        _heartbeatManager = State(initialValue: HeartbeatManager())

        _authManager = State(
            initialValue: AuthManager(authService: authService)
        )
        self.pairingService = pairingService
        self.friendService = friendService
        _focusStatsReporter = State(
            initialValue: FocusStatsReporter(friendService: friendService)
        )

        let managedSettingsStore = ManagedSettingsStore()
        let screenTimeManager = ScreenTimeManager(store: managedSettingsStore)
        _screenTimeManager = State(initialValue: screenTimeManager)

        // The restriction and notification services are shared between
        // SessionManager (for paired sessions) and the solo timer flow.
        // Both paths target the same ManagedSettingsStore and notification
        // center, so the last writer wins - which is correct because solo
        // and paired sessions are mutually exclusive.
        let restrictionService = ManagedSettingsRestrictionService(
            screenTimeManager: screenTimeManager,
            store: managedSettingsStore
        )
        _restrictionCoordinator = State(
            initialValue: RestrictionCoordinator(
                screenTimeManager: screenTimeManager,
                restrictionService: restrictionService
            )
        )

        // Push notification sender writes requests to Firestore; a Cloud
        // Function picks them up and delivers via FCM. If the function
        // isn't deployed yet, documents accumulate harmlessly while the
        // Firestore real-time listener handles the in-app sync path.
        let notificationService = LocalNotificationService(
            pushSender: pushSender
        )

        // The focus scheduler registers DeviceActivity monitoring intervals
        // so the Monitor extension can reapply or remove shields even if
        // the user force-quits the app mid-session.
        let focusScheduler = FocusActivityScheduler()

        let sessionManager = SessionManager(
            syncService: syncService,
            restrictionService: restrictionService,
            notificationService: notificationService,
            focusScheduler: focusScheduler
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
            RootView(pairingService: pairingService, friendService: friendService)
                .environment(authManager)
                .environment(sessionManager)
                .environment(sessionObserver)
                .environment(fcmTokenManager)
                .environment(heartbeatManager)
                .environment(connectionMonitor)
                .environment(notificationManager)
                .environment(liveActivityManager)
                .environment(quickActionManager)
                .environment(focusIntentState)
                .environment(screenTimeManager)
                .environment(restrictionCoordinator)
                .environment(powerStateMonitor)
                .onChange(of: screenTimeManager.activitySelection) { _, _ in
                    restrictionCoordinator.refreshRestrictions()
                }
                .environment(onboardingManager)
                .environment(appearanceManager)
                .environment(focusStatsReporter)
                .preferredColorScheme(appearanceManager.preferredColorScheme)
                .task {
                    appDelegate.quickActionManager = quickActionManager
                    await authManager.start()
                    await notificationManager.refreshAuthorizationStatus()
                    screenTimeManager.refreshAuthorizationStatus()
                }
        }
        .modelContainer(for: StorageConfiguration.modelTypes)
    }
}
