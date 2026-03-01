import ActivityKit
import AppIntents

/// Live Activity intent that sets the timer paused state.
///
/// Triggered by the Pause / Resume button in the Dynamic Island's expanded
/// view. Updates the Live Activity inline and writes a bridge command for
/// the main app to process on next foreground transition.
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

    /// Desired paused state. `true` pauses, `false` resumes.
    var shouldPause: Bool

    init() {
        self.shouldPause = true
    }

    init(shouldPause: Bool) {
        self.shouldPause = shouldPause
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

        if shouldPause {
            guard !state.isPaused else { return .result() }

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
        } else {
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
        }

        return .result()
    }
}
