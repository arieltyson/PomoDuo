import FamilyControls
import SwiftUI

/// Screen Time authorization and blocked-app selection UI.
struct AppBlockingView: View {
    @Environment(ScreenTimeManager.self) private var screenTimeManager
    @Environment(\.scenePhase) private var scenePhase
    @State private var isPickerPresented = false

    var body: some View {
        @Bindable var bindableScreenTimeManager = screenTimeManager

        Form {
            if screenTimeManager.isAuthorized {
                AuthorizedAppBlockingContent(
                    screenTimeManager: screenTimeManager,
                    onPickApps: { isPickerPresented = true }
                )
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                UnauthorizedAppBlockingContent(
                    screenTimeManager: screenTimeManager
                )
                .transition(.opacity)
            }
        }
        .animation(
            .easeInOut(duration: 0.35),
            value: screenTimeManager.isAuthorized
        )
        .navigationTitle("App Blocking")
        .familyActivityPicker(
            isPresented: $isPickerPresented,
            selection: $bindableScreenTimeManager.activitySelection
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

// MARK: - Unauthorized Content

private struct UnauthorizedAppBlockingContent: View {
    @Environment(\.openURL) private var openURL

    let screenTimeManager: ScreenTimeManager

    var body: some View {
        Section {
            VStack(spacing: 16) {
                // Hero icon — shield with clear visual weight.
                Image(systemName: content.heroSymbol)
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

                Text(content.title)
                    .font(.headline)

                Text(content.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)

                if content.showsContinueButton {
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
                } else if content.showsOpenSettingsButton {
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

    private var content: UnauthorizedContentVariant {
        switch screenTimeManager.authorizationStatus {
        case .denied:
            .denied
        case .notDetermined, .approved, .approvedWithDataAccess:
            .notDetermined
        @unknown default:
            .notDetermined
        }
    }
}

private enum UnauthorizedContentVariant {
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

    /// SF Symbol that communicates the feature's purpose at a glance.
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

// MARK: - Authorized Content

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
            Button(
                "Choose Apps to Block",
                systemImage: "plus.app",
                action: onPickApps
            )
            .accessibilityHint("Opens Apple's app picker.")
            .accessibilityInputLabels([
                "Choose Apps to Block", "Choose Apps", "Select",
            ])

            if screenTimeManager.hasSelectedApps {
                BlockSelectionSummary(screenTimeManager: screenTimeManager)

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

// MARK: - Supporting Views

private struct BlockSelectionSummary: View {
    let screenTimeManager: ScreenTimeManager

    var body: some View {
        let appCount = screenTimeManager.activitySelection.applicationTokens
            .count
        let categoryCount = screenTimeManager.activitySelection.categoryTokens
            .count
        let webDomainCount = screenTimeManager.activitySelection
            .webDomainTokens.count

        VStack(alignment: .leading) {
            if appCount > 0 {
                let appWord = appCount == 1 ? "app" : "apps"
                Text("\(appCount) \(appWord) selected")
            }

            if webDomainCount > 0 {
                let domainWord =
                    webDomainCount == 1 ? "website" : "websites"
                Text("\(webDomainCount) \(domainWord) selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if categoryCount > 0 {
                let categoryWord =
                    categoryCount == 1 ? "category" : "categories"
                Text("\(categoryCount) \(categoryWord) selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
