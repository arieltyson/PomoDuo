import FamilyControls
import SwiftUI

/// Root view for the Settings tab.
struct SettingsView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(ScreenTimeManager.self) private var screenTimeManager
    @Environment(AppearanceManager.self) private var appearanceManager
    @Environment(NotificationManager.self) private var notificationManager
    @State private var feedbackCategory: FeedbackCategory?

    var body: some View {
        @Bindable var bindableAppearanceManager = appearanceManager

        Form {
            AccountSection(authManager: authManager)

            Section("Focus") {
                NavigationLink {
                    TimerSettingsView()
                } label: {
                    Label("Timer Durations", systemImage: "timer")
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
                            AppBlockingStatusBadge(
                                screenTimeManager: screenTimeManager
                            )
                        }
                    } icon: {
                        Image(systemName: "hourglass")
                    }
                }
            }

            Section("Appearance") {
                Picker(
                    "Appearance",
                    selection: $bindableAppearanceManager.selectedAppearance
                ) {
                    ForEach(AppAppearance.allCases) { appearance in
                        Text(appearance.title)
                            .tag(appearance)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityHint(
                    "Sets app appearance to system, light, or dark."
                )

                Text(appearanceManager.selectedAppearance.detailText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Preferences") {
                NavigationLink {
                    NotificationPreferencesView()
                } label: {
                    Label {
                        HStack {
                            Text("Notifications")
                            Spacer()
                            NotificationStatusBadge(
                                notificationManager: notificationManager
                            )
                        }
                    } icon: {
                        Image(systemName: "bell.fill")
                    }
                }
            }

            Section("Feedback") {
                Button("Report a Bug", systemImage: "ladybug") {
                    feedbackCategory = .bug
                }

                Button("Suggest a Feature", systemImage: "lightbulb") {
                    feedbackCategory = .feature
                }
            }
        }
        .sheet(item: $feedbackCategory) { category in
            FeedbackView(category: category)
        }
        .alert("Account Error", isPresented: authErrorIsPresented) {
            Button("OK") {
                authManager.clearError()
            }
        } message: {
            if let authError = authManager.authError {
                Text(authError)
            }
        }
        .navigationTitle("Settings")
    }

    private var authErrorIsPresented: Binding<Bool> {
        Binding(
            get: { authManager.authError != nil },
            set: { isPresented in
                if !isPresented {
                    authManager.clearError()
                }
            }
        )
    }
}

// MARK: - Subviews

private struct AccountSection: View {
    let authManager: AuthManager

    var body: some View {
        Section {
            if let currentUser = authManager.currentUser {
                NavigationLink {
                    AccountView(authManager: authManager)
                } label: {
                    SignedInAccountRow(user: currentUser)
                }
            } else if authManager.isLoading {
                HStack {
                    ProgressView()
                    Text("Signing in…")
                        .foregroundStyle(.secondary)
                }
            } else {
                // Signed out - offer Apple sign-in as primary action.
                SignInWithAppleButtonView(label: .signIn) {
                    Task {
                        await authManager.signInWithApple()
                    }
                }
                .listRowInsets(
                    EdgeInsets(
                        top: 12,
                        leading: 16,
                        bottom: 12,
                        trailing: 16
                    )
                )

                Button(
                    "Continue as Guest",
                    systemImage: "person.crop.circle.dashed"
                ) {
                    Task {
                        await authManager.signInAnonymously()
                    }
                }
                .foregroundStyle(.secondary)
                .accessibilityHint("Creates a local guest account.")
            }
        } header: {
            Text("Account")
        } footer: {
            if let currentUser = authManager.currentUser,
                currentUser.isAnonymous
            {
                Text(
                    "Guest accounts can't be recovered after reinstalling. Tap to link your Apple ID."
                )
            }
        }
    }
}

private struct SignedInAccountRow: View {
    let user: AuthUser

    var body: some View {
        HStack {
            Image(systemName: accountSymbol)
                .font(.title2)
                .foregroundStyle(
                    user.isAnonymous ? .secondary : AppColors.lavender
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading) {
                Text(user.displayName)
                    .font(.subheadline)
                    .bold()

                HStack(spacing: 4) {
                    if user.authProvider == .apple {
                        Image(systemName: "apple.logo")
                            .font(.caption2)
                    }

                    Text(statusText)
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }

            Spacer()

            if user.isAnonymous {
                // Subtle upgrade indicator for anonymous users.
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .accessibilityLabel("Account not linked")
            } else {
                Text(String(user.id.prefix(8)))
                    .font(.caption2)
                    .monospaced()
                    .foregroundStyle(.tertiary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Signed in as \(user.displayName)")
        .accessibilityHint("Tap to manage your account.")
    }

    private var accountSymbol: String {
        switch user.authProvider {
        case .anonymous:
            "person.crop.circle.dashed"
        case .apple:
            "person.crop.circle.fill.badge.checkmark"
        case .email:
            "person.crop.circle.fill"
        }
    }

    private var statusText: String {
        switch user.authProvider {
        case .anonymous:
            "Guest"
        case .apple:
            "Apple ID"
        case .email:
            "Signed In"
        }
    }
}

private struct AppBlockingStatusBadge: View {
    let screenTimeManager: ScreenTimeManager

    var body: some View {
        if screenTimeManager.isAuthorized && screenTimeManager.hasSelectedApps {
            let blockedCount =
                screenTimeManager.activitySelection.applicationTokens.count
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
        } else {
            Text("Off")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .accessibilityLabel("App blocking not enabled")
        }
    }
}

private struct NotificationStatusBadge: View {
    let notificationManager: NotificationManager

    var body: some View {
        if notificationManager.isAuthorized {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(AppColors.success)
                .accessibilityLabel("Notifications enabled")
        } else if notificationManager.hasCheckedAuthorization {
            Text("Off")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Notifications disabled")
        }
    }
}
