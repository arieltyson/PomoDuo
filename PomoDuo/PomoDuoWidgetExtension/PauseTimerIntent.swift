import ActivityKit
import AppIntents

/// Live Activity intent that pauses the running timer.
struct PauseTimerIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Pause Timer"
    static var description: IntentDescription? = IntentDescription(
        "Pause the Pomodoro timer."
    )
    static var openAppWhenRun: Bool { false }
    static var authenticationPolicy: IntentAuthenticationPolicy {
        .alwaysAllowed
    }

    // `supportedModes` is iOS 26.0+ (per the AppIntents SDK in
    // Xcode 26). The project's deployment target is iOS 26.2, so no
    // `@available` wrapper is needed. The previous wrapper claimed
    // `iOS 18.0`, which was wrong in both directions — it didn't
    // actually gate anything on iOS 26-only runtimes, and it made
    // CI toolchains that *didn't* know the iOS 26 SDK (Xcode 16.4
    // on `macos-latest`) fail to parse the property's type.
    //
    // `.background` alone is correct here: this Live Activity
    // pause button has no UI surface and `openAppWhenRun` is
    // already `false`, so the prior `[.background, .foreground(.dynamic)]`
    // set was internally contradictory.
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
        return .result()
    }
}
