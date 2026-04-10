import FamilyControls
import SwiftUI

/// Screen Time app blocking — routes to setup or inline selection based on
/// authorization state.
///
/// - **Authorized**: Embeds `FamilyActivityPicker` directly as the page
///   content. The user reaches the selection interface immediately with
///   no intermediate management screen.
/// - **Unauthorized**: Shows a dedicated setup screen focused on getting
///   Screen Time permission.
struct AppBlockingView: View {
    @Environment(ScreenTimeManager.self) private var screenTimeManager
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if screenTimeManager.isAuthorized {
                AppBlockingSelectionContent()
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                AppBlockingSetupContent(screenTimeManager: screenTimeManager)
                    .transition(.opacity)
            }
        }
        .navigationTitle("App Blocking")
        .animation(.easeInOut(duration: 0.35), value: screenTimeManager.isAuthorized)
        .task {
            screenTimeManager.refreshAuthorizationStatus()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            screenTimeManager.refreshAuthorizationStatus()
        }
    }
}

// MARK: - Inline Selection (Authorized)

/// Embeds `FamilyActivityPicker` directly as the screen content.
///
/// The picker is the entire authorized experience — no summary screen,
/// no intermediate management layer. Users check and uncheck items
/// directly. A toolbar button provides "Clear All" as the only
/// supplementary action.
private struct AppBlockingSelectionContent: View {
    @Environment(ScreenTimeManager.self) private var screenTimeManager
    @State private var isShowingClearConfirmation = false

    /// Forces `FamilyActivityPicker` to recreate after a programmatic
    /// selection clear. The picker is UIKit-backed and does not visually
    /// refresh when its bound selection changes outside of user interaction.
    @State private var pickerID = UUID()

    var body: some View {
        @Bindable var bindable = screenTimeManager

        FamilyActivityPicker(
            selection: $bindable.activitySelection
        )
        .id(pickerID)
        .toolbar {
            if screenTimeManager.hasSelectedApps {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear All", systemImage: "trash") {
                        isShowingClearConfirmation = true
                    }
                    .tint(AppColors.stopTint)
                    .accessibilityHint("Removes all blocked app selections.")
                    .accessibilityInputLabels(["Clear All", "Clear", "Reset"])
                }
            }
        }
        .alert(
            "Clear Selection?",
            isPresented: $isShowingClearConfirmation
        ) {
            Button("Clear All", role: .destructive) {
                screenTimeManager.clearSelection()
                pickerID = UUID()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove all blocked apps and categories.")
        }
    }
}

// MARK: - Setup Content (Unauthorized)

/// Dedicated Screen Time authorization screen. Handles both the
/// first-time permission request and the denied/restricted state.
private struct AppBlockingSetupContent: View {
    let screenTimeManager: ScreenTimeManager
    @Environment(\.openURL) private var openURL

    var body: some View {
        Form {
            Section {
                VStack(spacing: 16) {
                    Image(systemName: variant.heroSymbol)
                        .font(.system(size: 44))
                        .foregroundStyle(AppColors.lavender.gradient)
                        .symbolRenderingMode(.hierarchical)
                        .symbolEffect(
                            .pulse.wholeSymbol,
                            options: .repeating.speed(0.4),
                            isActive: !screenTimeManager.isRequestingAuthorization
                        )
                        .frame(width: 80, height: 80)
                        .background(AppColors.lavender.opacity(0.1), in: .circle)
                        .padding(.top, 8)
                        .accessibilityHidden(true)

                    Text(variant.title)
                        .font(.headline)

                    Text(variant.message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)

                    if variant.showsContinueButton {
                        Button {
                            Task {
                                await screenTimeManager.requestAuthorization()
                            }
                        } label: {
                            if screenTimeManager.isRequestingAuthorization {
                                ProgressView()
                                    .controlSize(.regular)
                            } else {
                                HStack(spacing: 6) {
                                    Image(systemName: "shield.lefthalf.filled")
                                        .font(.body.weight(.semibold))
                                    Text("Continue")
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppColors.lavender)
                        .controlSize(.large)
                        .padding(.top, 4)
                        .accessibilityLabel("Continue")
                        .accessibilityHint(
                            "Shows Apple's Screen Time permission request."
                        )
                        .accessibilityInputLabels(["Continue", "Next"])
                        .disabled(screenTimeManager.isRequestingAuthorization)
                    } else if variant.showsOpenSettingsButton {
                        Button("Open Settings", systemImage: "gear") {
                            if let settingsURL = URL(
                                string: UIApplication.openSettingsURLString
                            ) {
                                openURL(settingsURL)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppColors.lavender)
                        .controlSize(.large)
                        .padding(.top, 4)
                        .accessibilityHint(
                            "Opens the system Settings app to manage Screen Time access."
                        )
                        .accessibilityInputLabels(["Open Settings", "Settings"])
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
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

    private var variant: SetupVariant {
        switch screenTimeManager.authorizationStatus {
        case .denied:
            .denied
        case .notDetermined, .approved, .approvedWithDataAccess:
            .notDetermined
        @unknown default:
            .notDetermined
        }
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

// MARK: - Setup Variants

private enum SetupVariant {
    case notDetermined
    case denied

    var title: String {
        switch self {
        case .notDetermined: "Block Distracting Apps"
        case .denied: "Finish Setup in Settings"
        }
    }

    var message: String {
        switch self {
        case .notDetermined:
            "During focus sessions, selected apps can be automatically blocked with Screen Time. Tap Continue to review Apple's permission request."
        case .denied:
            "Screen Time access is currently off for PomoDuo. Open Settings to allow app blocking, then return here to choose the apps you want to block."
        }
    }

    var heroSymbol: String {
        switch self {
        case .notDetermined: "shield.lefthalf.filled.badge.checkmark"
        case .denied: "gear.badge.xmark"
        }
    }

    var showsContinueButton: Bool {
        self == .notDetermined
    }

    var showsOpenSettingsButton: Bool {
        self == .denied
    }
}
