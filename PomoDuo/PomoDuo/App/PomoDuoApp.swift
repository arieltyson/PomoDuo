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
    @State private var notificationManager = NotificationManager()
    @State private var liveActivityManager = LiveActivityManager()
    @State private var focusIntentState = FocusIntentState.shared
    @State private var screenTimeManager = ScreenTimeManager()
    @State private var appearanceManager = AppearanceManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(notificationManager)
                .environment(liveActivityManager)
                .environment(focusIntentState)
                .environment(screenTimeManager)
                .environment(appearanceManager)
                .preferredColorScheme(appearanceManager.preferredColorScheme)
                .task {
                    await notificationManager.refreshAuthorizationStatus()
                    screenTimeManager.refreshAuthorizationStatus()
                }
        }
        .modelContainer(for: StorageConfiguration.modelTypes)
    }
}
