import FamilyControls
import SwiftUI

/// Screen Time app blocking — routes to setup or management based on
/// authorization state.
///
/// - **Authorized**: Shows the selection management view and auto-presents
///   the picker when no apps are selected yet.
/// - **Unauthorized**: Shows a dedicated setup screen focused on getting
///   Screen Time permission.
struct AppBlockingView: View {
    @Environment(ScreenTimeManager.self) private var screenTimeManager
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if screenTimeManager.isAuthorized {
                AppBlockingManagementContent()
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

// MARK: - Management Content (Authorized)

/// Selection management for authorized users. Auto-presents the
/// `FamilyActivityPicker` on first appearance when no apps are selected,
/// giving the user the lowest-friction path to their goal.
private struct AppBlockingManagementContent: View {
    @Environment(ScreenTimeManager.self) private var screenTimeManager
    @State private var isPickerPresented = false
    @State private var hasAutoPresented = false

    var body: some View {
        @Bindable var bindable = screenTimeManager

        Form {
            if screenTimeManager.hasSelectedApps {
                SelectedAppsSection(
                    screenTimeManager: screenTimeManager,
                    onEdit: { isPickerPresented = true }
                )
            } else {
                EmptyBlockingSection(
                    onChoose: { isPickerPresented = true }
                )
            }
        }
        .familyActivityPicker(
            isPresented: $isPickerPresented,
            selection: $bindable.activitySelection
        )
        .task {
            guard !screenTimeManager.hasSelectedApps, !hasAutoPresented else { return }
            hasAutoPresented = true
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            isPickerPresented = true
        }
    }
}

/// Shows the current selection summary with edit and clear actions.
private struct SelectedAppsSection: View {
    let screenTimeManager: ScreenTimeManager
    let onEdit: () -> Void

    var body: some View {
        Section("Blocked Apps") {
            BlockSelectionSummary(screenTimeManager: screenTimeManager)
        }

        Section {
            Button("Edit Selection", systemImage: "pencil", action: onEdit)
                .accessibilityHint("Opens Apple's app picker to change blocked apps.")
                .accessibilityInputLabels(["Edit Selection", "Edit", "Change"])

            Button(
                "Clear Selection",
                systemImage: "trash",
                role: .destructive
            ) {
                screenTimeManager.clearSelection()
            }
            .accessibilityHint("Removes all blocked app selections.")
            .accessibilityInputLabels(["Clear Selection", "Clear", "Reset"])
        }
    }
}

/// Empty state shown when authorized but no apps are selected.
private struct EmptyBlockingSection: View {
    let onChoose: () -> Void

    var body: some View {
        Section {
            VStack(spacing: 16) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 36))
                    .foregroundStyle(AppColors.lavender.opacity(0.5))
                    .accessibilityHidden(true)

                Text("No Apps Blocked")
                    .font(.headline)

                Text("Choose apps and categories to block during focus sessions.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        }

        Section {
            Button(
                "Choose Apps to Block",
                systemImage: "plus.app",
                action: onChoose
            )
            .accessibilityHint("Opens Apple's app picker.")
            .accessibilityInputLabels(["Choose Apps to Block", "Choose Apps", "Select"])
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

// MARK: - Selection Summary

private struct BlockSelectionSummary: View {
    let screenTimeManager: ScreenTimeManager

    private var allCategoriesSelected: Bool {
        screenTimeManager.activitySelection.categoryTokens.count
            >= ShieldSessionContext.allCategoriesThreshold
    }

    var body: some View {
        let appCount = screenTimeManager.activitySelection.applicationTokens
            .count
        let categoryCount = screenTimeManager.activitySelection.categoryTokens
            .count
        let webDomainCount = screenTimeManager.activitySelection
            .webDomainTokens.count

        VStack(alignment: .leading) {
            if allCategoriesSelected {
                Text("All apps & categories selected")
            } else {
                if appCount > 0 {
                    let appWord = appCount == 1 ? "app" : "apps"
                    Text("\(appCount) \(appWord) selected")
                }

                if categoryCount > 0 {
                    let categoryWord =
                        categoryCount == 1 ? "category" : "categories"
                    Text("\(categoryCount) \(categoryWord) selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if webDomainCount > 0 {
                let domainWord =
                    webDomainCount == 1 ? "website" : "websites"
                Text("\(webDomainCount) \(domainWord) selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if allCategoriesSelected {
                Text(
                    "Some system apps may remain available due to iOS restrictions."
                )
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            summaryLabel(
                appCount: appCount,
                webDomainCount: webDomainCount,
                categoryCount: categoryCount
            )
        )
    }

    private func summaryLabel(
        appCount: Int,
        webDomainCount: Int,
        categoryCount: Int
    ) -> String {
        if allCategoriesSelected {
            var label = "All apps and categories selected for blocking"
            if webDomainCount > 0 {
                let domainWord = webDomainCount == 1 ? "website" : "websites"
                label += " and \(webDomainCount) \(domainWord)"
            }
            return label
        }

        var parts: [String] = []
        if appCount > 0 {
            let appWord = appCount == 1 ? "app" : "apps"
            parts.append("\(appCount) \(appWord)")
        }
        if webDomainCount > 0 {
            let domainWord = webDomainCount == 1 ? "website" : "websites"
            parts.append("\(webDomainCount) \(domainWord)")
        }
        if categoryCount > 0 {
            let categoryWord = categoryCount == 1 ? "category" : "categories"
            parts.append("\(categoryCount) \(categoryWord)")
        }
        return "\(parts.joined(separator: " and ")) selected for blocking"
    }
}
