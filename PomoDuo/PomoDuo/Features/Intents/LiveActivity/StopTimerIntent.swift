import ActivityKit
import AppIntents

/// Shared Live Activity action that stops the running timer.
///
/// This app-target counterpart mirrors the widget-extension intent so
/// execution succeeds even when the system resolves actions in app process.
struct StopTimerIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Stop Timer"
    static var description: IntentDescription? = IntentDescription(
        "Stop the Pomodoro timer."
    )

    static var openAppWhenRun: Bool { false }
    static var authenticationPolicy: IntentAuthenticationPolicy {
        .alwaysAllowed
    }

    @available(iOS 18.0, *)
    static var supportedModes: IntentModes {
        [.background, .foreground(.dynamic)]
    }

    func perform() async throws -> some IntentResult {
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
