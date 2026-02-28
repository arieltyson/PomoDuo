import ActivityKit
import AppIntents

/// Live Activity intent that toggles the timer between paused and running.
///
/// Triggered by the Pause / Resume button in the Dynamic Island's expanded
/// view. Updates the Live Activity inline and writes a bridge command for
/// the main app to process on next foreground transition.
struct TogglePauseIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Toggle Pause"
    static var description: IntentDescription? = IntentDescription(
        "Pause or resume the Pomodoro timer."
    )

    func perform() async throws -> some IntentResult {
        guard let activity = Activity<TimerActivityAttributes>.activities.first
        else {
            return .result()
        }

        let state = activity.content.state

        if state.isPaused {
            // Resume: restart the countdown from the frozen remaining time.
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
            // Pause: capture the exact remaining time and freeze.
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
