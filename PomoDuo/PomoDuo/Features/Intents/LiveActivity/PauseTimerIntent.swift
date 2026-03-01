import ActivityKit
import AppIntents

/// Shared Live Activity action that pauses the running timer.
struct PauseTimerIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Pause Timer"
    static let description: IntentDescription? = IntentDescription(
        "Pause the Pomodoro timer."
    )

    static var openAppWhenRun: Bool { false }
    static var authenticationPolicy: IntentAuthenticationPolicy {
        .alwaysAllowed
    }

    @available(iOS 18.0, *)
    static var supportedModes: IntentModes {
        [.background, .foreground(.dynamic)]
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
        return .result()
    }
}
