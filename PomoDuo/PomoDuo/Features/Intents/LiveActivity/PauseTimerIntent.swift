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

    // `supportedModes` is iOS 26.0+ (AppIntents SDK). Deployment
    // target is 26.2, so no `@available` wrapper is needed. The
    // previous `@available(iOS 18.0, *)` was wrong on both axes —
    // didn't gate anything for runtime, and made Xcode 16.4 (the
    // toolchain `macos-latest` still defaulted to on CI at the
    // time) fail to parse `IntentModes`. `.background` alone is
    // correct: `openAppWhenRun = false` above means foreground
    // continuation is explicitly undesired.
    static var supportedModes: IntentModes { .background }

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
