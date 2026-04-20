import FamilyControls
import SwiftUI

/// Screen Time authorization and blocked-app selection UI.
struct AppBlockingView: View {
    @Environment(ScreenTimeManager.self) private var screenTimeManager
    @Environment(\.scenePhase) private var scenePhase
    @State private var isPickerPresented = false

    var body: some View {
        Form {
            if screenTimeManager.isAuthorized {
                AuthorizedAppBlockingContent(
                    screenTimeManager: screenTimeManager,
                    onPickApps: { isPickerPresented = true }
                )
            } else {
                UnauthorizedAppBlockingContent(
                    screenTimeManager: screenTimeManager
                )
            }
        }
        .navigationTitle("App Blocking")
        .familyActivityPicker(
            isPresented: $isPickerPresented,
            selection: pickerSelection
        )
        .task {
            screenTimeManager.refreshAuthorizationStatus()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            screenTimeManager.refreshAuthorizationStatus()
        }
        .alert(
            "App Blocking Unavailable",
            isPresented: authorizationErrorAlertIsPresented
        ) {
            Button("OK") {
                screenTimeManager.clearAuthorizationError()
            }
        } message: {
            if let authorizationError = screenTimeManager.authorizationError {
                Text(authorizationError)
            }
        }
    }

    private var pickerSelection: Binding<FamilyActivitySelection> {
        Binding(
            get: { screenTimeManager.activitySelection },
            set: { draft in
                screenTimeManager.commitDraft(draft)
            }
        )
    }

    private var authorizationErrorAlertIsPresented: Binding<Bool> {
        Binding(
            get: { screenTimeManager.authorizationError != nil },
            set: { isPresented in
                if !isPresented {
                    screenTimeManager.clearAuthorizationError()
                }
            }
        )
    }
}

private struct UnauthorizedAppBlockingContent: View {
    let screenTimeManager: ScreenTimeManager

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

                Text(
                    "During focus sessions, selected apps can be automatically blocked with Screen Time."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

                Button {
                    Task {
                        await screenTimeManager.requestAuthorization()
                    }
                } label: {
                    if screenTimeManager.isRequestingAuthorization {
                        ProgressView()
                            .controlSize(.regular)
                    } else {
                        Label(
                            "Enable App Blocking",
                            systemImage: "lock.shield"
                        )
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.lavender)
                .controlSize(.large)
                .padding(.top, 8)
                .accessibilityHint(
                    "Requests Screen Time authorization for app blocking."
                )
                .disabled(screenTimeManager.isRequestingAuthorization)
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
        Section {
            FocusShieldHeroCard()
                .listRowInsets(
                    EdgeInsets(top: 8, leading: 0, bottom: 12, trailing: 0)
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }

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
                Button("Clear Selection", systemImage: "trash", role: .destructive) {
                    screenTimeManager.clearSelection()
                }
                .accessibilityHint("Removes all blocked app selections.")
            }
        }
    }
}
