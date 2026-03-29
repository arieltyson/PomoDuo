import SwiftUI

/// User-facing notification preferences for PomoDuo.
///
/// Provides controls for requesting system notification authorization
/// and toggling individual notification categories. When authorization
/// is denied at the system level, a deep-link to Settings.app is shown.
struct NotificationPreferencesView: View {
    @Environment(NotificationManager.self) private var notificationManager

    @State private var timerEndEnabled = true
    @State private var partnerActivityEnabled = true
    @State private var friendRequestsEnabled = true

    var body: some View {
        Form {
            AuthorizationSection(notificationManager: notificationManager)

            if notificationManager.isAuthorized {
                CategorySection(
                    timerEndEnabled: $timerEndEnabled,
                    partnerActivityEnabled: $partnerActivityEnabled,
                    friendRequestsEnabled: $friendRequestsEnabled
                )
            }

            InfoSection()
        }
        .navigationTitle("Notifications")
        .task {
            await notificationManager.refreshAuthorizationStatus()
        }
    }
}

// MARK: - Sections

private struct AuthorizationSection: View {
    let notificationManager: NotificationManager

    var body: some View {
        Section {
            HStack {
                Label {
                    Text("Notifications")
                } icon: {
                    Image(systemName: statusSymbol)
                        .foregroundStyle(statusColor)
                }

                Spacer()

                Text(statusLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Notifications \(statusLabel)")

            if !notificationManager.hasCheckedAuthorization {
                ProgressView("Checking authorization…")
            } else if !notificationManager.isAuthorized {
                AuthorizationActionView(
                    notificationManager: notificationManager
                )
            }
        } header: {
            Text("Status")
        } footer: {
            if notificationManager.isAuthorized {
                Text(
                    "PomoDuo can send timer alerts, friend request alerts, and partner activity updates."
                )
            }
        }
    }

    private var statusSymbol: String {
        notificationManager.isAuthorized
            ? "checkmark.circle.fill"
            : "bell.slash.fill"
    }

    private var statusColor: Color {
        notificationManager.isAuthorized ? AppColors.success : .secondary
    }

    private var statusLabel: String {
        if !notificationManager.hasCheckedAuthorization {
            return "Checking…"
        }
        return notificationManager.isAuthorized ? "Enabled" : "Disabled"
    }
}

private struct AuthorizationActionView: View {
    let notificationManager: NotificationManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(
                "Enable notifications so you never miss a friend request, timer alert, or partner session."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)

            HStack {
                Button("Enable Notifications", systemImage: "bell.badge") {
                    Task {
                        await notificationManager.requestPermission()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.lavender)
                .controlSize(.small)

                OpenSettingsButton()
            }
        }
    }
}

private struct OpenSettingsButton: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button("Open Settings", systemImage: "gear") {
            if let settingsURL = URL(
                string: UIApplication.openSettingsURLString
            ) {
                openURL(settingsURL)
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .accessibilityHint(
            "Opens the system Settings app to manage notification permissions."
        )
    }
}

private struct CategorySection: View {
    @Binding var timerEndEnabled: Bool
    @Binding var partnerActivityEnabled: Bool
    @Binding var friendRequestsEnabled: Bool

    var body: some View {
        Section {
            Toggle(isOn: $timerEndEnabled) {
                Label("Timer Alerts", systemImage: "timer")
            }
            .accessibilityHint(
                "Notifies you when a focus or break period ends."
            )

            Toggle(isOn: $partnerActivityEnabled) {
                Label("Partner Activity", systemImage: "person.2.fill")
            }
            .accessibilityHint(
                "Notifies you when your partner starts, pauses, or ends a session."
            )

            Toggle(isOn: $friendRequestsEnabled) {
                Label("Friend Requests", systemImage: "person.badge.plus")
            }
            .accessibilityHint(
                "Notifies you when someone sends you a friend request."
            )
        } header: {
            Text("Categories")
        } footer: {
            Text(
                "These preferences are stored locally and apply to this device only."
            )
        }
        .tint(AppColors.lavender)
    }
}

private struct InfoSection: View {
    var body: some View {
        Section {
            Label {
                Text(
                    "PomoDuo uses notifications to alert you about friend requests, partner activity, and timer events. No notification data is shared with third parties."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            } icon: {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
