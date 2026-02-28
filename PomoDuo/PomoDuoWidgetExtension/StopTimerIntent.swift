import ActivityKit
import AppIntents

/// Live Activity intent that stops the timer and ends all activities.
///
/// Triggered by the Stop button in the Dynamic Island's expanded view.
/// Writes a bridge command for the main app, then ends every active
/// timer Live Activity.
struct StopTimerIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Stop Timer"
    static var description: IntentDescription? = IntentDescription(
        "Stop the Pomodoro timer."
    )

    func perform() async throws -> some IntentResult {
        // Write bridge command before ending so the main app can sync.
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
