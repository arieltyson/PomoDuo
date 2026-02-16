//
//  PomoDuoApp.swift
//  PomoDuo
//
//  Created by Ariel Tyson on 14/2/26.
//

import SwiftUI
import SwiftData

@main
struct PomoDuoApp: App {
    @State private var authManager = AuthManager()
    @State private var sessionManager = SessionManager()
    @State private var notificationManager = NotificationManager()
    @State private var liveActivityManager = LiveActivityManager()
    @State private var focusIntentState = FocusIntentState.shared
    @State private var screenTimeManager: ScreenTimeManager
    @State private var restrictionCoordinator: RestrictionCoordinator
    @State private var onboardingManager = OnboardingManager()
    @State private var appearanceManager = AppearanceManager()

    init() {
        let screenTimeManager = ScreenTimeManager()
        _screenTimeManager = State(initialValue: screenTimeManager)
        _restrictionCoordinator = State(
            initialValue: RestrictionCoordinator(screenTimeManager: screenTimeManager)
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authManager)
                .environment(sessionManager)
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
