import ActivityKit
import AppIntents
import DeviceActivity
import ManagedSettings

/// Shared Live Activity action that stops the running timer.
///
/// This app-target counterpart mirrors the widget-extension intent so
/// execution succeeds even when the system resolves actions in app process.
/// Immediately removes shields and clears session context so blocked apps
/// become usable without reopening PomoDuo.
struct StopTimerIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Stop Timer"
    static let description: IntentDescription? = IntentDescription(
        "Stop the Pomodoro timer."
    )

    static var openAppWhenRun: Bool { false }
    static var authenticationPolicy: IntentAuthenticationPolicy {
        .alwaysAllowed
    }

    // See ``PauseTimerIntent`` for the rationale.
    static var supportedModes: IntentModes { .background }

    @MainActor
    func perform() async throws -> some IntentResult {
        // Remove shields immediately so blocked apps are usable right away.
        let store = ManagedSettingsStore()
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        store.shield.webDomainCategories = nil

        // Cancel DeviceActivity monitoring to prevent the monitor extension
        // from reapplying shields after this intent completes.
        let center = DeviceActivityCenter()
        center.stopMonitoring([
            DeviceActivityName(
                rawValue: ShieldSessionContext.focusActivityID
            )
        ])

        // Clear shared session context so extensions know the session ended.
        ShieldSessionContext.clearSession()

        // Write bridge command so the main app can sync its in-memory state.
        LiveActivityBridge.write(.stop)

        for activity in Activity<TimerActivityAttributes>.activities {
            let state = activity.content.state
            let finalState = TimerActivityAttributes.ContentState(
                phase: state.phase,
                currentRound: state.currentRound,
                targetEndDate: .now,
                isPaused: false,
                phaseDuration: state.phaseDuration
            )

            await activity.end(
                ActivityContent(state: finalState, staleDate: nil),
                dismissalPolicy: .immediate
            )
        }

        return .result()
    }
}
