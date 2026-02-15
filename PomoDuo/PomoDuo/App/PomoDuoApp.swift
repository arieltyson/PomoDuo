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

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(notificationManager)
                .task {
                    await notificationManager.refreshAuthorizationStatus()
                }
        }
        .modelContainer(for: StorageConfiguration.modelTypes)
    }
}
