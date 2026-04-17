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
                label: "Canonical (includeEntireCategory)",
                value: selection.isCanonical ? "Yes" : "No"
            )
        } header: {
            Text("Selection")
        } footer: {
            if !selection.isCanonical {
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
                    ? "Will be written" : "Not used"
            )
            DiagnosticsRow(
                label: "Specific web channel",
                value: policy.writesSpecificWebDomainsChannel
                    ? "Will be written" : "Not used"
            )
        } header: {
            Text("Policy (computed)")
        } footer: {
            Text(
                "Computed by ShieldPolicyMapper from the current selection. Describes the policy the app would write at the next focus session."
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
                    ? "Set (\(channels.applicationsCount))" : "Not set"
            )
            DiagnosticsRow(
                label: "App categories channel",
                value: channels.applicationCategoriesConfigured
                    ? "Set" : "Not set"
            )
            DiagnosticsRow(
                label: "Web domains channel",
                value: channels.webDomainsConfigured
                    ? "Set (\(channels.webDomainsCount))" : "Not set"
            )
            DiagnosticsRow(
                label: "Web categories channel",
                value: channels.webDomainCategoriesConfigured
                    ? "Set" : "Not set"
            )
        } header: {
            Text("ManagedSettings (configured by app)")
        } footer: {
            Text(
                "These are the values the app last wrote. iOS does not expose whether it is currently enforcing them — that is the system's responsibility."
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
    var displayLabel: String {
        if #available(iOS 26.4, *), self == .approvedWithDataAccess {
            return "Approved with data access"
        }
        switch self {
        case .notDetermined: return "Not determined"
        case .denied: return "Denied"
        case .approved: return "Approved"
        @unknown default: return "Unknown"
        }
    }
}

private extension ShieldPolicyMapper.ApplicationPolicyCase {
    var displayLabel: String {
        switch self {
        case .none: "None"
        case .specific: "Selected categories"
        }
    }
}

private extension ShieldPolicyMapper.WebDomainPolicyCase {
    var displayLabel: String {
        switch self {
        case .none: "None"
        case .specific: "Selected categories"
        }
    }
}
