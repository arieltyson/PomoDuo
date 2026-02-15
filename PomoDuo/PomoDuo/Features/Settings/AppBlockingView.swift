//
//  AppBlockingView.swift
//  PomoDuo
//
//  Created by Codex on 2/15/26.
//

import FamilyControls
import SwiftUI

/// Screen Time authorization and blocked-app selection UI.
struct AppBlockingView: View {
    @Environment(ScreenTimeManager.self) private var screenTimeManager
    @State private var isPickerPresented = false

    var body: some View {
        @Bindable var bindableScreenTimeManager = screenTimeManager

        Form {
            if screenTimeManager.isAuthorized {
                AuthorizedAppBlockingContent(
                    screenTimeManager: screenTimeManager,
                    onPickApps: { isPickerPresented = true }
                )
            } else {
                UnauthorizedAppBlockingContent {
                    Task {
                        await screenTimeManager.requestAuthorization()
                    }
                }
            }
        }
        .navigationTitle("App Blocking")
        .familyActivityPicker(
            isPresented: $isPickerPresented,
            selection: $bindableScreenTimeManager.activitySelection
        )
    }
}

private struct UnauthorizedAppBlockingContent: View {
    let onAuthorize: () -> Void

    var body: some View {
        Section {
            VStack {
                Image(systemName: "hourglass.badge.plus")
                    .font(.system(.largeTitle, design: .rounded))
                    .foregroundStyle(AppColors.lavender)
                    .accessibilityHidden(true)

                Text("Block Distracting Apps")
                    .font(.headline)
                    .padding(.top, 8)

                Text("During focus sessions, selected apps can be automatically blocked with Screen Time.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("Enable App Blocking", systemImage: "lock.shield", action: onAuthorize)
                    .buttonStyle(.borderedProminent)
                    .tint(AppColors.lavender)
                    .controlSize(.large)
                    .padding(.top, 8)
                    .accessibilityHint("Requests Screen Time authorization for app blocking.")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }
}

private struct AuthorizedAppBlockingContent: View {
    let screenTimeManager: ScreenTimeManager
    let onPickApps: () -> Void

    var body: some View {
        Section("Status") {
            HStack {
                Label("Screen Time", systemImage: "checkmark.shield.fill")
                    .foregroundStyle(AppColors.success)
                Spacer()
                Text("Authorized")
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Screen Time authorized")
        }

        Section("Blocked Apps") {
            Button("Choose Apps to Block", systemImage: "plus.app", action: onPickApps)
                .accessibilityHint("Opens Apple's app picker.")

            if screenTimeManager.hasSelectedApps {
                BlockSelectionSummary(screenTimeManager: screenTimeManager)

                Button("Clear Selection", systemImage: "trash", role: .destructive) {
                    screenTimeManager.clearSelection()
                }
                .accessibilityHint("Removes all blocked app selections.")
            }
        }

        Section("How It Works") {
            HowItWorksStepRow(
                systemImage: "play.fill",
                title: "Start a focus session",
                detail: "Selected apps are shielded automatically."
            )
            HowItWorksStepRow(
                systemImage: "shield.fill",
                title: "Stay focused",
                detail: "Blocked apps are unavailable while focus is active."
            )
            HowItWorksStepRow(
                systemImage: "checkmark.circle.fill",
                title: "Session ends",
                detail: "Shields are removed automatically."
            )
        }
    }
}

private struct BlockSelectionSummary: View {
    let screenTimeManager: ScreenTimeManager

    var body: some View {
        let appCount = screenTimeManager.activitySelection.applicationTokens.count
        let categoryCount = screenTimeManager.activitySelection.categoryTokens.count

        VStack(alignment: .leading) {
            if appCount > 0 {
                let appWord = appCount == 1 ? "app" : "apps"
                Text("\(appCount) \(appWord) selected")
            }

            if categoryCount > 0 {
                let categoryWord = categoryCount == 1 ? "category" : "categories"
                Text("\(categoryCount) \(categoryWord) selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(summaryLabel(appCount: appCount, categoryCount: categoryCount))
    }

    private func summaryLabel(appCount: Int, categoryCount: Int) -> String {
        var parts: [String] = []
        if appCount > 0 {
            let appWord = appCount == 1 ? "app" : "apps"
            parts.append("\(appCount) \(appWord)")
        }
        if categoryCount > 0 {
            let categoryWord = categoryCount == 1 ? "category" : "categories"
            parts.append("\(categoryCount) \(categoryWord)")
        }
        return "\(parts.joined(separator: " and ")) selected for blocking"
    }
}

private struct HowItWorksStepRow: View {
    let systemImage: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: systemImage)
                .foregroundStyle(AppColors.lavender)
                .frame(width: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading) {
                Text(title)
                    .font(.subheadline)
                    .bold()
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
