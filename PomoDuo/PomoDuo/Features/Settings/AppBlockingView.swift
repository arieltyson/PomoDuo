import FamilyControls
import ManagedSettings
import SwiftUI

/// Screen Time app blocking — routes to setup or to the summary-first
/// authorized experience.
///
/// - **Authorized**: ``AppBlockingSummaryView`` is the primary surface.
///   It shows the user **what PomoDuo is configured to block** — the
///   categories, specific apps, and web domains they picked in the
///   editor. Category carve-outs (apps or domains the user deselected
///   from inside a blocked category) are surfaced in their own
///   "Category Exceptions" section so the user has a direct swipe-to-
///   re-block affordance the picker structurally can't provide. The
///   ``FamilyActivityPicker`` is reachable as a pushed **Editor** view
///   via an explicit "Edit App Blocking" button.
/// - **Unauthorized**: ``AppBlockingSetupContent`` owns the Screen Time
///   permission flow (first-time request and denied/restricted state).
///
/// ### Why summary-first
///
/// `FamilyActivitySelection` has no public exception field (verified
/// against Apple's docs — the struct only exposes `applicationTokens`,
/// `categoryTokens`, `webDomainTokens`, and `includeEntireCategory`).
/// When the user commits a "shield this category but exempt this app"
/// intent via ``ScreenTimeManager/commitDraft(_:)``, the derived
/// carve-outs live on ``ScreenTimeManager/categoryExceptions`` and
/// ``ScreenTimeManager/webDomainCategoryExceptions`` — state the
/// picker structurally cannot round-trip. Making the picker the front
/// door would leave those carve-outs invisible. The summary view is the
/// app's first-class representation of **configured** state; the
/// picker is just its editor.
///
/// ### What the summary does *not* claim
///
/// PomoDuo cannot enumerate every app installed on the device. The
/// summary intentionally avoids any "unblocked apps" framing — an app
/// the user never added to a blocked category simply doesn't appear
/// anywhere in this screen. Only carve-outs from currently-shielded
/// categories are trackable, and that is the narrow claim the
/// "Category Exceptions" section makes.
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

/// Configured-state summary: shows the user what PomoDuo is set up to
/// block and exposes direct controls for category carve-outs — the one
/// thing the picker structurally can't represent.
///
/// ### What this screen covers
///
/// - The "Summary" section at the bottom counts only the things the
///   user **picked to block**: categories, specific apps, web domains.
///   Carve-outs are intentionally excluded from the count ledger.
///   Mixing inputs (picked-to-block) with derived carve-outs
///   (exempted-from-a-block) invites the false inference "blocked −
///   exceptions = the apps that are actually unblocked", which PomoDuo
///   cannot accurately answer. Apple does not expose the universe of
///   installed apps.
/// - "Category Exceptions" (and its web counterpart) lists only
///   carve-outs tracked in ``ScreenTimeManager/categoryExceptions`` /
///   ``ScreenTimeManager/webDomainCategoryExceptions``. An app the
///   user never added to a blocked category won't appear here, because
///   there is no carve-out to surface.
///
/// ### Implementation notes
///
/// - Carve-out rows use Apple's `Label(ApplicationToken)` /
///   `Label(WebDomainToken)` initializer — per `DisplayingActivityLabels`
///   in FamilyControls — so each row renders the real app icon + name
///   (or the web-domain string). Reading `Application.localizedDisplayName`
///   from the main app target is unsupported (Apple returns `nil`
///   outside Shield Configuration extensions), so `Label(token)` is the
///   only documented path.
/// - Swipe-to-reblock on each carve-out row calls the direct
///   management API on ``ScreenTimeManager`` so the user never has to
///   reopen the picker to undo a carve-out.
private struct AppBlockingSummaryView: View {
    @Environment(ScreenTimeManager.self) private var screenTimeManager
    @State private var isShowingClearExceptionsConfirmation = false

    var body: some View {
        Form {
            EditorPushSection()
            AppExceptionsSection(
                onClearAllRequested: {
                    isShowingClearExceptionsConfirmation = true
                }
            )
            WebDomainExceptionsSection()
            SummarySection()
        }
        .scrollIndicators(.hidden)
        .alert(
            "Clear Category Exceptions?",
            isPresented: $isShowingClearExceptionsConfirmation
        ) {
            Button("Clear", role: .destructive) {
                screenTimeManager.clearAllCategoryExceptions()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "Every app you've carved out of a blocked category will be shielded again the next time a focus session runs."
            )
        }
    }
}

/// Terse counts of what the user has picked to block. Carve-outs are
/// intentionally omitted from this section — they are a separate axis
/// (derived, not picked) and listing them here alongside inputs would
/// imply a false "blocked minus exceptions = unblocked" arithmetic
/// that PomoDuo cannot truthfully compute.
///
/// Rendered last on the page so the primary edit action and the
/// exception carve-out controls stay above the fold; counts are a
/// read-only ledger and belong at the bottom.
private struct SummarySection: View {
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
        } header: {
            Text("Summary")
        } footer: {
            if screenTimeManager.hasSelectedApps {
                Text(
                    "PomoDuo shields these items during focus sessions."
                )
            } else {
                Text(
                    "Nothing is currently set up to block. Tap Edit App Blocking above to choose apps, categories, or web domains."
                )
            }
        }
    }
}

/// Lists the per-app carve-outs PomoDuo is tracking — apps the user
/// deselected from inside a currently-shielded category while keeping
/// the category itself blocked. Surfaces a swipe-to-re-block action
/// because the picker structurally cannot represent or round-trip
/// these carve-outs.
///
/// ### Scope — read this before changing copy
///
/// This section is **not** a list of "all apps that aren't blocked."
/// PomoDuo has no access to the device's installed-app inventory; an
/// app the user never added to a blocked category will never appear
/// here. The only state this section represents is the carve-out set
/// derived at commit time by
/// ``ScreenTimeManager/commitDraft(_:)`` and stored on
/// ``ScreenTimeManager/categoryExceptions``.
///
/// Row rendering uses Apple's `Label(ApplicationToken)` so each row
/// shows the system-rendered app icon + name.
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
                    Text("Category Exceptions")
                    Spacer()
                    if screenTimeManager.categoryExceptions.count > 1 {
                        Button("Clear All") {
                            onClearAllRequested()
                        }
                        .font(.caption)
                        .buttonStyle(.borderless)
                        .accessibilityHint(
                            "Removes every category carve-out and re-blocks the apps inside their categories."
                        )
                    }
                }
            } footer: {
                Text(
                    "Apps you've deselected from inside a blocked category during editing — their category stays shielded, these specific apps don't. Swipe a row to re-block. Only carve-outs you made in the editor appear here; apps you never added to a blocked category aren't tracked. iOS observationally caps this list at \(ScreenTimeManager.categoryExceptionsLimit) items, shared with web carve-outs."
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
/// ``ScreenTimeManager/commitDraft(_:)`` derives web carve-outs from
/// the draft diff the same way. Like its app counterpart, this section
/// represents **only** the carve-outs PomoDuo tracked at commit time;
/// it is not an "unblocked domains" list.
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
                    Text("Web Category Exceptions")
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
                        .accessibilityHint(
                            "Removes every web carve-out and re-blocks these domains inside their categories."
                        )
                    }
                }
            } footer: {
                Text(
                    "Web domains you've deselected from inside a blocked category — their category stays shielded, these specific domains don't. Swipe a row to re-block. Only carve-outs you made in the editor appear here."
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

/// CTA for the pushed editor. The picker lives behind an explicit
/// button so the user understands that editing is a distinct action
/// from reading the committed state.
///
/// **Diagnostics visibility.** The "App Blocking Diagnostics"
/// `NavigationLink` is gated behind `#if DEBUG`, so it appears only in
/// development and TestFlight-from-source builds — never in App Store
/// builds. The diagnostics view itself
/// (``AppBlockingDiagnosticsView``), the
/// ``SettingsDestination/appBlockingDiagnostics`` enum case, and the
/// `RootView` destination resolver all remain in the codebase
/// unchanged so the developer experience is unaffected; we strip only
/// the user-facing entry point from release builds. Apple's docs allow
/// shipping diagnostics surfaces but the current copy is engineer-
/// oriented (raw `monitor.intervalDidStart` / `.specificExcept` /
/// `ManagedSettings` terminology), and the Reset action it leads to
/// is destructive, so hiding it from end users is the safer default.
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

            #if DEBUG
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
            #endif
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
            // Apple's `FamilyActivityPicker` binds a
            // `FamilyActivitySelection`, which structurally cannot
            // encode category carve-outs (the struct has no exception
            // field — verified against
            // `FamilyControls.swiftinterface`). That means an app the
            // user has exempted from a blocked category on the summary
            // screen can still appear checked in this picker. A thin
            // banner at the top names that limitation so the user's
            // mental model stays aligned with the summary, which is
            // the authoritative source of truth for carve-outs.
            .safeAreaInset(edge: .top, spacing: 0) {
                CategoryExceptionsBanner()
            }
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
            // Apple's docs and HIG steer destructive state-change
            // confirmations (discard-unsaved-work, delete-draft,
            // revert) to the centered `.alert` modal rather than
            // `.confirmationDialog`. The confirmation dialog API
            // renders as a popover anchored to the source control in
            // regular size classes — and in our case, attached to
            // the UIKit-backed `FamilyActivityPicker`, even in
            // compact widths it was surfacing as a pointer-style
            // popover against the Cancel button. `.alert` presents
            // as a centered modal on every size class independent
            // of anchor position, matching the behavior the rest of
            // iOS uses for discard-changes confirmations (Pages,
            // Safari Reader, Mail drafts, Notes, Shortcuts).
            .alert(
                "Discard Changes?",
                isPresented: $isShowingDiscardConfirmation
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

/// Non-blocking banner pinned above ``FamilyActivityPicker`` that names
/// a structural limitation of Apple's picker: `FamilyActivitySelection`
/// has no exception field (verified against the public Swift
/// interface), so an app the user has carved out of a blocked category
/// can still render as checked inside the picker even when the summary
/// screen is correctly tracking it as a Category Exception.
///
/// The banner only appears when the manager is holding one or more
/// carve-outs — `hasSelectedApps` without carve-outs means the picker
/// is truthful about the full state and no disclaimer is needed. When
/// the user clears every carve-out, the banner disappears on its own.
///
/// Kept deliberately thin: one `info.circle.fill` glyph + two short
/// sentences. `.regularMaterial` in a `Rectangle` matches the iOS 26
/// banner pattern in Mail / Safari Reader; the Divider at the bottom
/// separates it from the UIKit-backed picker below.
private struct CategoryExceptionsBanner: View {
    @Environment(ScreenTimeManager.self) private var screenTimeManager

    var body: some View {
        if hasTrackedCarveOuts {
            bannerBody
        }
    }

    private var hasTrackedCarveOuts: Bool {
        !screenTimeManager.categoryExceptions.isEmpty
            || !screenTimeManager.webDomainCategoryExceptions.isEmpty
    }

    private var bannerBody: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .font(.callout.weight(.semibold))
                .foregroundStyle(AppColors.lavender)
                .accessibilityHidden(true)

            Text(
                "Apps you've carved out of a blocked category may still appear selected here — Apple's picker doesn't expose Category Exceptions. Manage carve-outs on App Blocking."
            )
            .font(.caption)
            .foregroundStyle(.primary)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: Rectangle())
        .overlay(alignment: .bottom) {
            Divider()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Apps you have carved out of a blocked category may still appear selected in this picker. Apple's picker can't display Category Exceptions. Manage carve-outs on the App Blocking screen."
        )
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
