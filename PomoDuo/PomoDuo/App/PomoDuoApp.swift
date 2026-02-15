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
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: StorageConfiguration.modelTypes)
    }
}
