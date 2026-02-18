import FamilyControls
import SwiftUI

/// Root view for the Settings tab.
struct SettingsView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(ScreenTimeManager.self) private var screenTimeManager
    @Environment(AppearanceManager.self) private var appearanceManager

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
                Button(
                    "Sign In as Guest",
                    systemImage: "person.crop.circle.badge.plus"
                ) {
                    Task {
                        await authManager.signInAnonymously()
                    }
                }
                .accessibilityHint("Creates a local guest account.")
            }
        } header: {
            Text("Account")
        } footer: {
            if let currentUser = authManager.currentUser,
                currentUser.isAnonymous
            {
                Text(
                    "You are signed in as a guest. Tap to manage your account."
                )
            }
        }
    }
}

private struct SignedInAccountRow: View {
    let user: AuthUser

    var body: some View {
        HStack {
            Image(
                systemName: user.isAnonymous
                    ? "person.crop.circle.dashed" : "person.crop.circle.fill"
            )
            .font(.title2)
            .foregroundStyle(user.isAnonymous ? .secondary : AppColors.lavender)
            .accessibilityHidden(true)

            VStack(alignment: .leading) {
                Text(user.displayName)
                    .font(.subheadline)
                    .bold()

                Text(user.isAnonymous ? "Guest" : "Signed In")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(String(user.id.prefix(8)))
                .font(.caption2)
                .monospaced()
                .foregroundStyle(.tertiary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Signed in as \(user.displayName)")
        .accessibilityHint("Tap to manage your account.")
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
        }
    }
}
