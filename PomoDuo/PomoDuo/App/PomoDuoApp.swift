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
    @State private var friendRequestNotificationObserver: FriendRequestNotificationObserver
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
        _friendRequestNotificationObserver = State(
            initialValue: FriendRequestNotificationObserver(friendService: friendService)
        )

        let managedSettingsStore = ManagedSettingsStore()
        let screenTimeManager = ScreenTimeManager(store: managedSettingsStore)
        _screenTimeManager = State(initialValue: screenTimeManager)

        // The restriction service writes shield channels for both the solo
        // flow (via RestrictionCoordinator) and the paired flow (now also
        // via the coordinator, since SessionManager delegates Screen Time
        // side effects rather than owning them directly).
        let restrictionService = ManagedSettingsRestrictionService(
            screenTimeManager: screenTimeManager,
            store: managedSettingsStore
        )

        // The focus scheduler registers DeviceActivity monitoring intervals
        // so the Monitor extension can reapply or remove shields even if
        // the user force-quits the app mid-session. The coordinator owns it.
        let focusScheduler = FocusActivityScheduler()

        let restrictionCoordinator = RestrictionCoordinator(
            screenTimeManager: screenTimeManager,
            restrictionService: restrictionService,
            focusScheduler: focusScheduler
        )
        _restrictionCoordinator = State(initialValue: restrictionCoordinator)

        // Push notification sender writes requests to Firestore; a Cloud
        // Function picks them up and delivers via FCM. If the function
        // isn't deployed yet, documents accumulate harmlessly while the
        // Firestore real-time listener handles the in-app sync path.
        let notificationService = LocalNotificationService(
            pushSender: pushSender
        )

        // SessionManager delegates every paired-session Screen Time side
        // effect to the coordinator. This is what makes remote updates
        // (which arrive through SessionObserver → SessionManager even when
        // no Partner view is mounted) reach the same single owner that the
        // solo flow already drives.
        let sessionManager = SessionManager(
            syncService: syncService,
            notificationService: notificationService,
            restrictionCoordinator: restrictionCoordinator
        )
        _sessionManager = State(initialValue: sessionManager)
        _sessionObserver = State(
            initialValue: SessionObserver(
                syncService: syncService,
                sessionManager: sessionManager
            )
        )
    }

    @Environment(\.scenePhase) private var scenePhase

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
                    screenTimeManager.refreshRuntimeHealth(
                        focusIsActive: restrictionCoordinator.isRestricting
                    )
                }
                .onChange(of: screenTimeManager.categoryExceptions) { _, _ in
                    // Mirrors the activitySelection observer because
                    // ``ScreenTimeManager/commitDraft(_:)`` may update
                    // exceptions independently of the selection (e.g.,
                    // a draft that re-selects a previously-excepted app
                    // clears the exception without changing the selection
                    // shape). The coordinator's `refreshRestrictions` is
                    // idempotent so the worst case — both observers
                    // firing for one commit — is a redundant apply.
                    restrictionCoordinator.refreshRestrictions()
                    screenTimeManager.refreshRuntimeHealth(
                        focusIsActive: restrictionCoordinator.isRestricting
                    )
                }
                .onChange(
                    of: screenTimeManager.webDomainCategoryExceptions
                ) { _, _ in
                    // Web-domain symmetry with the app-exceptions
                    // observer above. Direct removeWebDomainCategoryException
                    // calls from the summary view mutate this set without
                    // touching activitySelection — this observer is what
                    // drives the refresh in that case.
                    restrictionCoordinator.refreshRestrictions()
                    screenTimeManager.refreshRuntimeHealth(
                        focusIsActive: restrictionCoordinator.isRestricting
                    )
                }
                .onChange(of: scenePhase) { _, newPhase in
                    // Foregrounding is the moment background-induced
                    // Screen Time pipeline drift becomes visible. Refresh
                    // the runtime health so any active-session chip
                    // reflects the current truth; the per-session
                    // reconcile hooks in TimerView and
                    // ActivePairedSessionView do the actual repair.
                    guard newPhase == .active else { return }
                    screenTimeManager.refreshRuntimeHealth(
                        focusIsActive: restrictionCoordinator.isRestricting
                    )
                }
                .environment(onboardingManager)
                .environment(appearanceManager)
                .environment(focusStatsReporter)
                .environment(friendRequestNotificationObserver)
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
