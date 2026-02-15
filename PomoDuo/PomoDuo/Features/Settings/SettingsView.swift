//
//  SettingsView.swift
//  PomoDuo
//
//  Created by Codex on 2/15/26.
//

import SwiftUI

/// Root view for the Settings tab.
struct SettingsView: View {
    var body: some View {
        Form {
            Section("Focus") {
                NavigationLink {
                    TimerSettingsView()
                } label: {
                    Label("Timer Durations", systemImage: "timer")
                }

                NavigationLink {
                    SessionHistoryView()
                } label: {
                    Label("Session History", systemImage: "clock.arrow.circlepath")
                }
            }

            Section("Integrations") {
                NavigationLink {
                    ContentUnavailableView {
                        Label("Screen Time", systemImage: "hourglass")
                    } description: {
                        Text("App blocking during focus sessions is coming soon.")
                    }
                    .navigationTitle("Screen Time")
                } label: {
                    Label("App Blocking", systemImage: "hourglass")
                }
            }

            Section("Preferences") {
                NavigationLink {
                    ContentUnavailableView {
                        Label("Notifications", systemImage: "bell.fill")
                    } description: {
                        Text("Notification preferences are coming soon.")
                    }
                    .navigationTitle("Notifications")
                } label: {
                    Label("Notifications", systemImage: "bell.fill")
                }
            }
        }
        .navigationTitle("Settings")
    }
}
