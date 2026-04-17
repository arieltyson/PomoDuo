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

/// Embeds `FamilyActivityPicker` over a local **draft** selection, with
/// an explicit Save action that commits the draft atomically into
/// ``ScreenTimeManager``.
///
/// **Why this is draft-bound rather than directly bound.** Binding the
/// picker straight to ``ScreenTimeManager/activitySelection`` makes
/// every picker tap mutate the live, enforced selection — and because
/// `PomoDuoApp` observes `activitySelection` and re-applies restrictions
/// on every change, every intermediate picker state is briefly enforced.
/// During an active focus session that produces transient unblocking as
/// the picker's internal state churns toward its final shape (especially
/// when deselecting an app from a category with `includeEntireCategory:
/// true`, which the picker resolves by demoting the category and
/// emitting a partial `applicationTokens`). The draft model keeps the
/// picker's internal mutations local; nothing reaches the live shield
/// pipeline until the user confirms with Save.
///
/// The Save handler routes through ``ScreenTimeManager/commitDraft(_:)``,
/// which derives any category-with-exception intent by diffing the
/// draft against the currently-committed selection — see that method's
/// doc comment for the rationale.
private struct AppBlockingSelectionContent: View {
    @Environment(ScreenTimeManager.self) private var screenTimeManager
    @Environment(\.dismiss) private var dismiss

    /// Local draft the picker mutates. Seeded from the manager's
    /// committed selection on first appear so the picker shows the
    /// current state; thereafter the user's edits stay local until
    /// Save.
    @State private var draft: FamilyActivitySelection =
        FamilyActivitySelection(includeEntireCategory: true)
    @State private var hasSeededDraft = false
    @State private var isShowingClearConfirmation = false
    @State private var isShowingDiscardConfirmation = false

    /// Forces `FamilyActivityPicker` to recreate after a programmatic
    /// draft clear. The picker is UIKit-backed and does not visually
    /// refresh when its bound selection changes outside of user
    /// interaction.
    @State private var pickerID = UUID()

    var body: some View {
        FamilyActivityPicker(selection: $draft)
            .id(pickerID)
            .onAppear {
                seedDraftIfNeeded()
            }
            .navigationBarBackButtonHidden(hasUncommittedChanges)
            .toolbar { toolbarContent }
            .alert(
                "Clear Selection?",
                isPresented: $isShowingClearConfirmation
            ) {
                Button("Clear All", role: .destructive) {
                    draft = FamilyActivitySelection(
                        includeEntireCategory: true
                    )
                    pickerID = UUID()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(
                    "This will clear every app and category in this draft. Tap Save to apply, or Cancel to keep your previous selection."
                )
            }
            .confirmationDialog(
                "Discard changes?",
                isPresented: $isShowingDiscardConfirmation,
                titleVisibility: .visible
            ) {
                Button("Discard Changes", role: .destructive) {
                    dismiss()
                }
                Button("Keep Editing", role: .cancel) {}
            } message: {
                Text(
                    "Your edits to App Blocking haven't been saved. Leaving will discard them."
                )
            }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if hasUncommittedChanges {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    isShowingDiscardConfirmation = true
                }
                .tint(AppColors.stopTint)
                .accessibilityHint(
                    "Discards your unsaved changes to App Blocking."
                )
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            NavigationLink(
                value: SettingsDestination.appBlockingDiagnostics
            ) {
                Image(systemName: "stethoscope")
            }
            .accessibilityLabel("App Blocking Diagnostics")
            .accessibilityHint(
                "Inspect the configured Screen Time state and reset it if something looks wrong."
            )
        }

        if hasDraftItems {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Clear All", systemImage: "trash") {
                    isShowingClearConfirmation = true
                }
                .tint(AppColors.stopTint)
                .accessibilityHint(
                    "Clears the draft selection. Tap Save to apply."
                )
                .accessibilityInputLabels(["Clear All", "Clear", "Reset"])
            }
        }

        if hasUncommittedChanges {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    commit()
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.lavender)
                .accessibilityHint(
                    "Applies your App Blocking edits. If a focus session is running, the changes take effect immediately."
                )
            }
        }
    }

    /// Seeds the draft from the manager's current committed selection
    /// the first time this view appears. Subsequent appearances (e.g.
    /// returning from the diagnostics push) preserve any in-flight
    /// edits so the user doesn't lose work navigating away briefly.
    private func seedDraftIfNeeded() {
        guard !hasSeededDraft else { return }
        draft = screenTimeManager.activitySelection
        hasSeededDraft = true
    }

    private var hasDraftItems: Bool {
        !draft.applicationTokens.isEmpty
            || !draft.categoryTokens.isEmpty
            || !draft.webDomainTokens.isEmpty
    }

    /// Whether the draft differs from the manager's last-committed
    /// selection. `FamilyActivitySelection` conforms to `Equatable`
    /// over its three token sets and the `includeEntireCategory` flag,
    /// so this is a true "are there unsaved changes" signal.
    private var hasUncommittedChanges: Bool {
        draft != screenTimeManager.activitySelection
    }

    private func commit() {
        screenTimeManager.commitDraft(draft)
        // Re-seed our own knowledge of the committed state so the
        // Save/Cancel/back-button affordances flip back to "clean".
        draft = screenTimeManager.activitySelection
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
