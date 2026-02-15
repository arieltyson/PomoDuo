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

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(notificationManager)
                .environment(liveActivityManager)
                .environment(focusIntentState)
                .task {
                    await notificationManager.refreshAuthorizationStatus()
                }
        }
        .modelContainer(for: StorageConfiguration.modelTypes)
    }
}
