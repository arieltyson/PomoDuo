import ActivityKit
import AppIntents

/// Shared Live Activity action that sets pause/resume state.
///
/// This app-target counterpart mirrors the widget-extension intent so
/// execution succeeds even when the system resolves actions in app process.
struct TogglePauseIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Toggle Pause"
    static let description: IntentDescription? = IntentDescription(
        "Pause or resume the Pomodoro timer."
    )

    static var openAppWhenRun: Bool { false }
    static var authenticationPolicy: IntentAuthenticationPolicy {
        .alwaysAllowed
    }

    // See ``PauseTimerIntent`` for the rationale.
    static var supportedModes: IntentModes { .background }

    /// Desired paused state. `true` pauses, `false` resumes.
    var shouldPause: Bool

    init() {
        self.shouldPause = true
    }

    init(shouldPause: Bool) {
        self.shouldPause = shouldPause
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard
            let activity = Activity<TimerActivityAttributes>.activities.max(
                by: { lhs, rhs in
                    lhs.content.state.targetEndDate
                        < rhs.content.state.targetEndDate
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

            nonisolated(unsafe) let capturedActivity = activity
            await capturedActivity.update(
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

            nonisolated(unsafe) let capturedActivity = activity
            await capturedActivity.update(
                ActivityContent(state: newState, staleDate: newTargetEndDate)
            )

            LiveActivityBridge.write(.resume, remainingSeconds: remaining)
        }

        return .result()
    }
}
