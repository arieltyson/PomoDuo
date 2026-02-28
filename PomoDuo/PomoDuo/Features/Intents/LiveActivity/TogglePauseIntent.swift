import ActivityKit
import AppIntents

/// Shared Live Activity action that toggles pause/resume.
///
/// This app-target counterpart mirrors the widget-extension intent so
/// execution succeeds even when the system resolves actions in app process.
struct TogglePauseIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Toggle Pause"
    static var description: IntentDescription? = IntentDescription(
        "Pause or resume the Pomodoro timer."
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
        guard
            let activity = Activity<TimerActivityAttributes>.activities.max(
                by: { lhs, rhs in
                    lhs.content.state.targetEndDate < rhs.content.state.targetEndDate
                }
            )
        else {
            return .result()
        }

        let state = activity.content.state

        if state.isPaused {
            let remaining = state.pausedRemainingSeconds
            let newTargetEndDate = Date.now.addingTimeInterval(remaining)

            let newState = TimerActivityAttributes.ContentState(
                phase: state.phase,
                currentRound: state.currentRound,
                targetEndDate: newTargetEndDate,
                isPaused: false,
                phaseDuration: state.phaseDuration
            )

            await activity.update(
                ActivityContent(state: newState, staleDate: newTargetEndDate)
            )

            LiveActivityBridge.write(.resume, remainingSeconds: remaining)
        } else {
            let remaining = max(
                0,
                state.targetEndDate.timeIntervalSinceNow
            )

            let newState = TimerActivityAttributes.ContentState(
                phase: state.phase,
                currentRound: state.currentRound,
                targetEndDate: Date.now.addingTimeInterval(remaining),
                isPaused: true,
                phaseDuration: state.phaseDuration,
                pausedRemainingSeconds: remaining
            )

            await activity.update(
                ActivityContent(state: newState, staleDate: nil)
            )

            LiveActivityBridge.write(.pause, remainingSeconds: remaining)
        }

        return .result()
    }
}
