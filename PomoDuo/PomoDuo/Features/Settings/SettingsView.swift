//
//  SettingsView.swift
//  PomoDuo
//
//  Created by Codex on 2/15/26.
//

import SwiftUI
import FamilyControls

/// Root view for the Settings tab.
struct SettingsView: View {
    @Environment(ScreenTimeManager.self) private var screenTimeManager

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
                    AppBlockingView()
                } label: {
                    Label {
                        HStack {
                            Text("App Blocking")
                            Spacer()
                            AppBlockingStatusBadge(screenTimeManager: screenTimeManager)
                        }
                    } icon: {
                        Image(systemName: "hourglass")
                    }
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

private struct AppBlockingStatusBadge: View {
    let screenTimeManager: ScreenTimeManager

    var body: some View {
        if screenTimeManager.isAuthorized && screenTimeManager.hasSelectedApps {
            let blockedCount = screenTimeManager.activitySelection.applicationTokens.count
                + screenTimeManager.activitySelection.categoryTokens.count
            Text("\(blockedCount)")
                .font(.caption2)
                .bold()
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(AppColors.lavender, in: .capsule)
                .accessibilityLabel("\(blockedCount) items blocked")
        } else if screenTimeManager.isAuthorized {
            Text("Set Up")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .accessibilityLabel("App blocking authorized, no apps selected")
        }
    }
}
