import ActivityKit
import AppIntents

/// Live Activity intent that resumes a paused timer.
struct ResumeTimerIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Resume Timer"
    static var description: IntentDescription? = IntentDescription(
        "Resume the paused Pomodoro timer."
    )
    static var openAppWhenRun: Bool { false }
    static var authenticationPolicy: IntentAuthenticationPolicy {
        .alwaysAllowed
    }

    // See ``PauseTimerIntent`` for the rationale behind dropping the
    // `@available(iOS 18.0, *)` wrapper and narrowing to
    // `.background` — `supportedModes` is iOS 26.0+, the project's
    // deployment target is 26.2, and `openAppWhenRun = false` makes
    // foreground continuation irrelevant here.
    static var supportedModes: IntentModes { .background }

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
        guard state.isPaused else { return .result() }

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
        return .result()
    }
}
