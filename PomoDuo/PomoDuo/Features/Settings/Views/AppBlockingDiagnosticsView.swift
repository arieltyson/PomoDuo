import FamilyControls
import SwiftUI

/// On-device diagnostic surface for the Screen Time pipeline.
///
/// Renders ``ScreenTimeDiagnostics`` honestly: every row is labeled with
/// what the app *configured* or what the system has *registered* — never
/// "is currently shielding". iOS does not expose effective shielding, so
/// claiming it would be a lie. The destructive "Reset App Blocking" action
/// at the bottom is the recovery path for stale or inconsistent state.
struct AppBlockingDiagnosticsView: View {
    @Environment(ScreenTimeManager.self) private var screenTimeManager
    @Environment(\.scenePhase) private var scenePhase

    @State private var snapshot: ScreenTimeDiagnostics?
    @State private var isShowingResetConfirmation = false

    var body: some View {
        Form {
            if let snapshot {
                AuthorizationSection(authorization: snapshot.authorization)
                SelectionSection(selection: snapshot.selection)
                PolicySection(policy: snapshot.policy)
                ShieldChannelsSection(channels: snapshot.shieldChannels)
                MonitoringSection(monitoring: snapshot.monitoring)
                SessionContextSection(context: snapshot.sessionContext)
                ExtensionTelemetrySection(
                    telemetry: snapshot.extensionTelemetry
                )
                CapturedAtFooter(capturedAt: snapshot.capturedAt)
                ResetSection(
                    onResetRequested: { isShowingResetConfirmation = true }
                )
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .navigationTitle("App Blocking Diagnostics")
        .navigationBarTitleDisplayMode(.inline)
        .scrollIndicators(.hidden)
        .task {
            refreshSnapshot()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            refreshSnapshot()
        }
        .alert(
            "Reset App Blocking?",
            isPresented: $isShowingResetConfirmation
        ) {
            Button("Reset", role: .destructive) {
                screenTimeManager.resetAllScreenTimeState()
                refreshSnapshot()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "Clears the saved selection, removes any active shields, cancels the focus monitoring schedule, and rebuilds the picker from scratch. Screen Time authorization itself is not revoked."
            )
        }
    }

    private func refreshSnapshot() {
        snapshot = screenTimeManager.diagnosticsSnapshot()
    }
}

// MARK: - Sections

private struct AuthorizationSection: View {
    let authorization: ScreenTimeDiagnostics.Authorization

    var body: some View {
        Section("Authorization") {
            DiagnosticsRow(
                label: "Status",
                value: authorization.status.displayLabel
            )
            DiagnosticsRow(
                label: "Usable for shielding",
                value: authorization.isUsable ? "Yes" : "No"
            )
        }
    }
}

private struct SelectionSection: View {
    let selection: ScreenTimeDiagnostics.Selection

    var body: some View {
        Section {
            DiagnosticsRow(
                label: "Apps",
                value: "\(selection.applicationCount)"
            )
            DiagnosticsRow(
                label: "Categories",
                value: "\(selection.categoryCount)"
            )
            DiagnosticsRow(
                label: "Web domains",
                value: "\(selection.webDomainCount)"
            )
            DiagnosticsRow(
                label: "App exceptions",
                value: "\(selection.categoryExceptionCount)"
            )
            DiagnosticsRow(
                label: "Web domain exceptions",
                value: "\(selection.webDomainCategoryExceptionCount)"
            )
            DiagnosticsRow(
                label: "Canonical (includeEntireCategory)",
                value: selection.isCanonical ? "Yes" : "No"
            )
        } header: {
            Text("Selection")
        } footer: {
            if selection.categoryExceptionCount
                + selection.webDomainCategoryExceptionCount > 0
            {
                Text(
                    "Exceptions are items you deselected from a currently-shielded category. They're enforced via Apple's `.specific(_:except:)` shield policy (cap: 50 tokens shared across app and web-domain exceptions). Swipe a row in App Blocking to re-block an exception."
                )
            } else if !selection.isCanonical {
                Text(
                    "A non-canonical selection means the picker will lose exception semantics on the next edit. Reset to rebuild."
                )
            }
        }
    }
}

private struct PolicySection: View {
    let policy: ShieldPolicyMapper.DecisionShape

    var body: some View {
        Section {
            DiagnosticsRow(
                label: "App categories",
                value: policy.applicationCategories.displayLabel
            )
            DiagnosticsRow(
                label: "Web categories",
                value: policy.webDomainCategories.displayLabel
            )
            DiagnosticsRow(
                label: "Specific apps channel",
                value: policy.writesSpecificApplicationsChannel
                    ? "Will attempt" : "Not used"
            )
            DiagnosticsRow(
                label: "Specific web channel",
                value: policy.writesSpecificWebDomainsChannel
                    ? "Will attempt" : "Not used"
            )
        } header: {
            Text("Policy (computed)")
        } footer: {
            Text(
                "Computed by ShieldPolicyMapper from the current selection. 'Will attempt' means the app will write that channel at apply time; iOS may coalesce the write with the category shield or decline to persist it if it overlaps an active category block or exceeds internal caps. The app cannot observe which of those iOS chose."
            )
        }
    }
}

private struct ShieldChannelsSection: View {
    let channels: ScreenTimeDiagnostics.ShieldChannels

    var body: some View {
        Section {
            DiagnosticsRow(
                label: "Applications channel",
                value: channels.applicationsConfigured
                    ? "Reported set (\(channels.applicationsCount))"
                    : "Not reported"
            )
            DiagnosticsRow(
                label: "App categories channel",
                value: channels.applicationCategoriesConfigured
                    ? "Reported set" : "Not reported"
            )
            DiagnosticsRow(
                label: "Web domains channel",
                value: channels.webDomainsConfigured
                    ? "Reported set (\(channels.webDomainsCount))"
                    : "Not reported"
            )
            DiagnosticsRow(
                label: "Web categories channel",
                value: channels.webDomainCategoriesConfigured
                    ? "Reported set" : "Not reported"
            )
        } header: {
            Text("ManagedSettings (iOS read-back)")
        } footer: {
            Text(
                "What `ManagedSettingsStore` reports back when the app reads each shield channel. 'Not reported' does not necessarily mean 'not enforced' — iOS may persist a write internally (especially when a category shield already covers the same apps) without surfacing it through this read-back, and oversized writes can be coalesced silently. Use this as a signal that the write was accepted, not a guarantee of whether it was."
            )
        }
    }
}

private struct MonitoringSection: View {
    let monitoring: ScreenTimeDiagnostics.Monitoring

    var body: some View {
        Section {
            DiagnosticsRow(
                label: "Focus activity",
                value: monitoring.focusActivityRegistered
                    ? "Registered" : "Not registered"
            )
            DiagnosticsRow(
                label: "Schedule end",
                value: Self.formatDate(monitoring.focusScheduleEnd)
            )
        } header: {
            Text("DeviceActivity")
        } footer: {
            Text(
                "Reflects DeviceActivityCenter.activities and the current focus schedule. Drives the Monitor extension's reapply / remove callbacks."
            )
        }
    }

    private static func formatDate(_ date: Date?) -> String {
        guard let date else { return "—" }
        return date.formatted(date: .omitted, time: .shortened)
    }
}

private struct SessionContextSection: View {
    let context: ScreenTimeDiagnostics.SessionContext

    var body: some View {
        Section {
            DiagnosticsRow(
                label: "Session active",
                value: context.isActive ? "Yes" : "No"
            )
            DiagnosticsRow(
                label: "Phase",
                value: context.phase ?? "—"
            )
            DiagnosticsRow(
                label: "Target end",
                value: context.targetEndDate.map {
                    $0.formatted(date: .omitted, time: .shortened)
                } ?? "—"
            )
        } header: {
            Text("Shared Session Context (App Group)")
        } footer: {
            Text(
                "Read by the Shield and Monitor extensions. Should be cleared when no focus session is running."
            )
        }
    }
}

/// Surfaces invocation counts and last-observed-context from the Shield
/// and Monitor extensions so the user (and on-call debugging) can tell
/// whether iOS actually invoked them. Worded honestly: this section is
/// the closest *proxy* to real enforcement the app can produce. It is
/// not a guarantee that every blocked app will present the shield —
/// Apple's docs do not document whether
/// ``ShieldConfigurationDataSource/configuration(shielding:)`` is cached,
/// so the shield counts are a lower bound.
private struct ExtensionTelemetrySection: View {
    let telemetry: ShieldExtensionTelemetry.Snapshot

    var body: some View {
        Section {
            DiagnosticsRow(
                label: "Monitor · intervalDidStart",
                value: Self.eventValue(telemetry.monitorIntervalDidStart)
            )
            DiagnosticsRow(
                label: "Monitor · intervalDidEnd",
                value: Self.eventValue(telemetry.monitorIntervalDidEnd)
            )
            DiagnosticsRow(
                label: "Shield · for application",
                value: Self.eventValue(telemetry.shieldForApplication)
            )
            DiagnosticsRow(
                label: "Shield · for web domain",
                value: Self.eventValue(telemetry.shieldForWebDomain)
            )
            if let context = telemetry.lastObservedContext {
                DiagnosticsRow(
                    label: "Last-observed by",
                    value: context.byEvent.rawValue
                )
                DiagnosticsRow(
                    label: "Last-observed at",
                    value: context.observedAt.formatted(
                        date: .omitted,
                        time: .standard
                    )
                )
                DiagnosticsRow(
                    label: "Last-observed context active",
                    value: context.isSessionActive ? "Yes" : "No"
                )
                DiagnosticsRow(
                    label: "Last-observed phase",
                    value: context.phase ?? "—"
                )
                DiagnosticsRow(
                    label: "Last-observed target end",
                    value: Self.formatOptionalDate(context.targetEndDate)
                )
                if context.byEvent == .monitorIntervalDidStart
                    || context.byEvent == .monitorIntervalDidEnd
                {
                    DiagnosticsRow(
                        label: "Focus activity registered at callback",
                        value: context.focusActivityRegistered ? "Yes" : "No"
                    )
                }
            }
        } header: {
            Text("Extension Telemetry")
        } footer: {
            Text(
                "Counts of system callbacks to PomoDuo's Shield and Monitor extensions. This is the closest app-visible proxy to real Screen Time enforcement — iOS does not expose whether a specific app is currently shielded, but it does invoke these extensions when shielding happens. Shield counts are a lower bound because Apple doesn't document whether the shield configuration is cached per presentation."
            )
        }
    }

    private static func eventValue(
        _ snapshot: ShieldExtensionTelemetry.EventSnapshot
    ) -> String {
        guard let lastFiredAt = snapshot.lastFiredAt else {
            return "\(snapshot.count) · never fired"
        }
        let formattedDate = lastFiredAt.formatted(
            date: .omitted,
            time: .standard
        )
        return "\(snapshot.count) · last \(formattedDate)"
    }

    private static func formatOptionalDate(_ date: Date?) -> String {
        guard let date else { return "—" }
        return date.formatted(date: .omitted, time: .shortened)
    }
}

private struct CapturedAtFooter: View {
    let capturedAt: Date

    var body: some View {
        Section {
            DiagnosticsRow(
                label: "Snapshot taken",
                value: capturedAt.formatted(date: .omitted, time: .standard)
            )
        }
    }
}

private struct ResetSection: View {
    let onResetRequested: () -> Void

    var body: some View {
        Section {
            Button(role: .destructive) {
                onResetRequested()
            } label: {
                Label("Reset App Blocking", systemImage: "arrow.counterclockwise")
            }
            .accessibilityHint(
                "Removes all shields, cancels monitoring, clears the saved selection, and rebuilds the picker."
            )
        } footer: {
            Text(
                "Use this to recover from stale state without deleting and reinstalling PomoDuo. Screen Time authorization itself is unaffected."
            )
        }
    }
}

// MARK: - Row Primitive

private struct DiagnosticsRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.primary)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - Display Labels

private extension AuthorizationStatus {
    /// Human-readable label for each authorization state.
    ///
    /// `AuthorizationStatus.approvedWithDataAccess` is a **known** case in
    /// the iOS 26.4 SDK, so it must be handled explicitly — `@unknown
    /// default` is reserved for genuinely future cases Apple may add
    /// after this code was compiled, not for known-but-availability-
    /// gated cases. Hoisting an `if #available` check above a single
    /// switch doesn't narrow the enum for Swift's flow analysis, which
    /// is why the compiler still reports the switch as non-exhaustive.
    ///
    /// The idiomatic fix is an availability-branched pair of switches:
    /// each branch is exhaustive for the cases available in its
    /// deployment window, and both retain `@unknown default` so any
    /// *future* case Apple adds is still handled forward-compatibly.
    var displayLabel: String {
        if #available(iOS 26.4, *) {
            // Compiled against the iOS 26.4 SDK, every currently-known
            // case must be handled explicitly. `@unknown default` still
            // pulls its weight by catching any future case Apple adds.
            switch self {
            case .notDetermined: return "Not determined"
            case .denied: return "Denied"
            case .approved: return "Approved"
            case .approvedWithDataAccess: return "Approved with data access"
            @unknown default: return "Unknown"
            }
        } else {
            // Running on iOS 26.0–26.3. `.approvedWithDataAccess` is
            // `@available(iOS 26.4, *)` so it cannot be referenced by
            // name here — the compiler would reject the case pattern.
            // A plain `default` (not `@unknown default`) is the
            // idiomatic cover for "known-in-SDK but unreachable on this
            // OS version" in Swift: it silences the exhaustiveness
            // warning without pretending the case is unknown.
            switch self {
            case .notDetermined: return "Not determined"
            case .denied: return "Denied"
            case .approved: return "Approved"
            default: return "Unknown"
            }
        }
    }
}

private extension ShieldPolicyMapper.ApplicationPolicyCase {
    var displayLabel: String {
        switch self {
        case .none: "None"
        case .specific: "Selected categories"
        case .specificExcept: "Selected categories, with exceptions"
        }
    }
}

private extension ShieldPolicyMapper.WebDomainPolicyCase {
    var displayLabel: String {
        switch self {
        case .none: "None"
        case .specific: "Selected categories"
        case .specificExcept: "Selected categories, with exceptions"
        }
    }
}
