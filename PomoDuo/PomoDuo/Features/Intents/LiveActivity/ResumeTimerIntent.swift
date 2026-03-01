import ActivityKit
import AppIntents

/// Shared Live Activity action that resumes a paused timer.
struct ResumeTimerIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Resume Timer"
    static let description: IntentDescription? = IntentDescription(
        "Resume the paused Pomodoro timer."
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
        return .result()
    }
}
