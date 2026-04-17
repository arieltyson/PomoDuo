import FamilyControls
import ManagedSettings
import SwiftUI

/// Screen Time app blocking — routes to setup or to the summary-first
/// authorized experience.
///
/// - **Authorized**: ``AppBlockingSummaryView`` is the primary surface.
///   It shows the user a first-class representation of what PomoDuo is
///   currently enforcing — categories, specific apps, web domains, and
///   any category exceptions rendered with Apple's
///   `Label(ApplicationToken)` so each exception shows the real app
///   icon and name. The ``FamilyActivityPicker`` is reachable as a
///   pushed **Editor** view via an explicit "Edit App Blocking"
///   button.
/// - **Unauthorized**: ``AppBlockingSetupContent`` owns the Screen Time
///   permission flow (first-time request and denied/restricted state).
///
/// ### Why summary-first
///
/// `FamilyActivitySelection` has no public exception field. When the
/// user commits a "shield this category but exempt this app" intent
/// via ``ScreenTimeManager/commitDraft(_:)``, the derived exceptions
/// live on ``ScreenTimeManager/categoryExceptions`` and
/// ``ScreenTimeManager/webDomainCategoryExceptions`` — state the
/// picker structurally cannot round-trip. Making the picker the front
/// door would leave that enforced state invisible. The summary view is
/// the app's own truthful representation of the committed state; the
/// picker is just its editor.
struct AppBlockingView: View {
    @Environment(ScreenTimeManager.self) private var screenTimeManager
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if screenTimeManager.isAuthorized {
                AppBlockingSummaryView()
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

// MARK: - Summary (Authorized Root)

/// Committed-state summary: shows the user what PomoDuo is currently
/// enforcing and exposes direct controls for the pieces the picker
/// can't represent (the per-app and per-web-domain exception sets).
///
/// Architecture notes:
///
/// - The summary is the only place the raw committed state is rendered
///   in a way that's truthful about exceptions. Any other view that
///   needs to describe "what's blocked right now" should ultimately
///   defer here.
/// - Exception rows use Apple's `Label(ApplicationToken)` /
///   `Label(WebDomainToken)` initializer — per `DisplayingActivityLabels`
///   in FamilyControls — so each row renders the real app icon + name
///   (or the web-domain string). Reading `Application.localizedDisplayName`
///   from the main app target is unsupported (Apple returns `nil`
///   outside Shield Configuration extensions), so `Label(token)` is the
///   only documented path.
/// - Swipe-to-reblock on each exception row calls the direct
///   management API on ``ScreenTimeManager`` so the user never has to
///   reopen the picker to undo an exception.
private struct AppBlockingSummaryView: View {
    @Environment(ScreenTimeManager.self) private var screenTimeManager
    @State private var isShowingClearExceptionsConfirmation = false

    var body: some View {
        Form {
            StatusSection()
            BlockedItemsSection()
            AppExceptionsSection(
                onClearAllRequested: {
                    isShowingClearExceptionsConfirmation = true
                }
            )
            WebDomainExceptionsSection()
            EditorPushSection()
        }
        .scrollIndicators(.hidden)
        .alert(
            "Clear App Exceptions?",
            isPresented: $isShowingClearExceptionsConfirmation
        ) {
            Button("Clear", role: .destructive) {
                screenTimeManager.clearAllCategoryExceptions()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "Every app currently exempted from a blocked category will be shielded again the next time a focus session runs."
            )
        }
    }
}

/// Terse counts above the exception lists so the user can see the
/// committed state's shape at a glance without scrolling.
private struct StatusSection: View {
    @Environment(ScreenTimeManager.self) private var screenTimeManager

    var body: some View {
        Section {
            LabeledContent("Blocked categories") {
                Text(
                    "\(screenTimeManager.activitySelection.categoryTokens.count)"
                )
                .monospacedDigit()
            }
            LabeledContent("Specific apps") {
                Text(
                    "\(screenTimeManager.activitySelection.applicationTokens.count)"
                )
                .monospacedDigit()
            }
            LabeledContent("Web domains") {
                Text(
                    "\(screenTimeManager.activitySelection.webDomainTokens.count)"
                )
                .monospacedDigit()
            }
            LabeledContent("App exceptions") {
                Text("\(screenTimeManager.categoryExceptions.count)")
                    .monospacedDigit()
            }
            LabeledContent("Web domain exceptions") {
                Text(
                    "\(screenTimeManager.webDomainCategoryExceptions.count)"
                )
                .monospacedDigit()
            }
        } header: {
            Text("Currently Enforced")
        } footer: {
            if screenTimeManager.hasSelectedApps {
                Text(
                    "PomoDuo shields these items during focus sessions. Exceptions listed below are exempted from their blocked categories."
                )
            } else {
                Text(
                    "Nothing is currently set up to block. Tap Edit App Blocking below to choose apps, categories, or web domains."
                )
            }
        }
    }
}

/// When a user has an active selection, this section reiterates the
/// gist ("N categories blocked; M extra apps shielded") with a style
/// that visually grounds the picker-less view.
private struct BlockedItemsSection: View {
    @Environment(ScreenTimeManager.self) private var screenTimeManager

    var body: some View {
        if screenTimeManager.hasSelectedApps {
            Section("Summary") {
                Text(summarySentence)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(summarySentence)
            }
        }
    }

    private var summarySentence: String {
        let selection = screenTimeManager.activitySelection
        let categoryCount = selection.categoryTokens.count
        let appCount = selection.applicationTokens.count
        let webCount = selection.webDomainTokens.count
        let appExceptions = screenTimeManager.categoryExceptions.count
        let webExceptions =
            screenTimeManager.webDomainCategoryExceptions.count

        var parts: [String] = []
        if categoryCount > 0 {
            parts.append(
                "\(categoryCount) \(categoryCount == 1 ? "category" : "categories")"
            )
        }
        if appCount > 0 {
            parts.append(
                "\(appCount) \(appCount == 1 ? "app" : "apps")"
            )
        }
        if webCount > 0 {
            parts.append(
                "\(webCount) web \(webCount == 1 ? "domain" : "domains")"
            )
        }

        guard !parts.isEmpty else {
            return "No items configured yet."
        }

        let base = "Blocking " + parts.joined(separator: ", ") + "."
        let exceptionParts = [
            appExceptions > 0
                ? "\(appExceptions) app \(appExceptions == 1 ? "exception" : "exceptions")"
                : nil,
            webExceptions > 0
                ? "\(webExceptions) web \(webExceptions == 1 ? "exception" : "exceptions")"
                : nil,
        ].compactMap { $0 }

        if exceptionParts.isEmpty {
            return base
        }
        return base + " " + exceptionParts.joined(separator: " · ") + "."
    }
}

/// Lists app exceptions with swipe-to-reblock. Uses Apple's
/// `Label(ApplicationToken)` so each row shows the actual app icon and
/// name, rendered by the system.
private struct AppExceptionsSection: View {
    @Environment(ScreenTimeManager.self) private var screenTimeManager
    let onClearAllRequested: () -> Void

    var body: some View {
        if !screenTimeManager.categoryExceptions.isEmpty {
            Section {
                ForEach(exceptionTokensForRendering, id: \.self) { token in
                    Label(token)
                        .labelStyle(.titleAndIcon)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                screenTimeManager.removeCategoryException(
                                    token
                                )
                            } label: {
                                Label(
                                    "Re-block",
                                    systemImage: "shield.fill"
                                )
                            }
                        }
                        .accessibilityHint(
                            "Swipe to re-block this app inside its selected category."
                        )
                }
            } header: {
                HStack {
                    Text("App Exceptions")
                    Spacer()
                    if screenTimeManager.categoryExceptions.count > 1 {
                        Button("Clear All") {
                            onClearAllRequested()
                        }
                        .font(.caption)
                        .buttonStyle(.borderless)
                        .accessibilityHint(
                            "Removes every app exception and re-blocks them all."
                        )
                    }
                }
            } footer: {
                Text(
                    "These apps are currently exempted from one of your blocked categories. Swipe a row to re-block the app. Apple caps this list at \(ScreenTimeManager.categoryExceptionsLimit) items (shared with web exceptions)."
                )
            }
        }
    }

    /// Sorted token sequence used by `ForEach`. `ApplicationToken` is
    /// `Hashable` and `Sendable`; there is no public ordering key so
    /// we sort by `hashValue` to get a stable presentation order
    /// across launches within a process. Set membership is what
    /// matters for semantic correctness; the visual order is a
    /// stability concern, not a correctness one.
    private var exceptionTokensForRendering: [ApplicationToken] {
        screenTimeManager.categoryExceptions.sorted {
            $0.hashValue < $1.hashValue
        }
    }
}

/// Web-domain counterpart to ``AppExceptionsSection``. Symmetric in
/// behavior and semantics — the web-domain category shield has the
/// same partial-deselect failure mode, and
/// ``ScreenTimeManager/commitDraft(_:)`` derives web exceptions from
/// the draft diff the same way.
private struct WebDomainExceptionsSection: View {
    @Environment(ScreenTimeManager.self) private var screenTimeManager

    var body: some View {
        if !screenTimeManager.webDomainCategoryExceptions.isEmpty {
            Section {
                ForEach(
                    exceptionTokensForRendering,
                    id: \.self
                ) { token in
                    Label(token)
                        .labelStyle(.titleAndIcon)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                screenTimeManager
                                    .removeWebDomainCategoryException(token)
                            } label: {
                                Label(
                                    "Re-block",
                                    systemImage: "globe.badge.chevron.backward"
                                )
                            }
                        }
                        .accessibilityHint(
                            "Swipe to re-block this domain inside its selected category."
                        )
                }
            } header: {
                HStack {
                    Text("Web Domain Exceptions")
                    Spacer()
                    if screenTimeManager.webDomainCategoryExceptions.count
                        > 1
                    {
                        Button("Clear All") {
                            screenTimeManager
                                .clearAllWebDomainCategoryExceptions()
                        }
                        .font(.caption)
                        .buttonStyle(.borderless)
                    }
                }
            } footer: {
                Text(
                    "These web domains are currently exempted from one of your blocked categories. Swipe a row to re-block."
                )
            }
        }
    }

    private var exceptionTokensForRendering: [WebDomainToken] {
        screenTimeManager.webDomainCategoryExceptions.sorted {
            $0.hashValue < $1.hashValue
        }
    }
}

/// CTA for the pushed editor + diagnostics link. The picker lives
/// behind an explicit button so the user understands that editing is
/// a distinct action from reading the committed state.
private struct EditorPushSection: View {
    @Environment(ScreenTimeManager.self) private var screenTimeManager

    var body: some View {
        Section {
            NavigationLink {
                AppBlockingEditorView()
            } label: {
                Label(
                    screenTimeManager.hasSelectedApps
                        ? "Edit App Blocking"
                        : "Set Up App Blocking",
                    systemImage: "slider.horizontal.3"
                )
            }
            .accessibilityHint(
                "Opens Apple's activity picker to change which apps, categories, and web domains are blocked."
            )

            NavigationLink(
                value: SettingsDestination.appBlockingDiagnostics
            ) {
                Label(
                    "App Blocking Diagnostics",
                    systemImage: "stethoscope"
                )
            }
            .accessibilityHint(
                "Inspect the configured Screen Time state and reset it if something looks wrong."
            )
        }
    }
}

// MARK: - Editor (Pushed From Summary)

/// Hosts `FamilyActivityPicker` over a local draft selection with an
/// explicit Save action. Pushed from ``AppBlockingSummaryView``.
///
/// The draft/commit model stays exactly as it was — every picker
/// mutation stays local to this view until the user confirms with
/// Save, at which point ``ScreenTimeManager/commitDraft(_:)`` derives
/// any exception state and applies atomically.
private struct AppBlockingEditorView: View {
    @Environment(ScreenTimeManager.self) private var screenTimeManager
    @Environment(\.dismiss) private var dismiss

    @State private var draft: FamilyActivitySelection =
        FamilyActivitySelection(includeEntireCategory: true)
    @State private var hasSeededDraft = false
    @State private var isShowingClearConfirmation = false
    @State private var isShowingDiscardConfirmation = false

    /// Forces `FamilyActivityPicker` to recreate after a programmatic
    /// draft clear. The picker is UIKit-backed and does not visually
    /// refresh when its bound selection changes outside user
    /// interaction.
    @State private var pickerID = UUID()

    var body: some View {
        FamilyActivityPicker(selection: $draft)
            .id(pickerID)
            .navigationTitle("Edit App Blocking")
            .navigationBarTitleDisplayMode(.inline)
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

    private var hasUncommittedChanges: Bool {
        draft != screenTimeManager.activitySelection
    }

    private func commit() {
        screenTimeManager.commitDraft(draft)
        // Re-seed our own knowledge of the committed state so the
        // Save/Cancel/back-button affordances flip back to "clean".
        draft = screenTimeManager.activitySelection
        // Pop back to the summary so the user immediately sees the
        // committed result (including any derived exceptions) in its
        // first-class form rather than continuing to read the picker.
        dismiss()
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
