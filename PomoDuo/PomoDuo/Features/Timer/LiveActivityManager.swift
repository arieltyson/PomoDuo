import ActivityKit
import Foundation
import Observation
import OSLog

/// Owns the lifecycle of the timer Live Activity.
@MainActor
@Observable
final class LiveActivityManager {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.arieljtyson.PomoDuo",
        category: "LiveActivityManager"
    )

    /// Whether a timer Live Activity is currently active.
    private(set) var isActivityActive = false

    private var currentActivity: Activity<TimerActivityAttributes>?

    init() {
        endAllOrphanedActivities()
    }

    /// Starts a new timer Live Activity.
    /// Any previous activity is ended immediately first.
    func start(
        phase: TimerActivityAttributes.Phase,
        currentRound: Int,
        totalRounds: Int,
        targetEndDate: Date
    ) {
        endAllActivities()

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            isActivityActive = false
            return
        }

        let attributes = TimerActivityAttributes(totalRounds: totalRounds)
        let state = TimerActivityAttributes.ContentState(
            phase: phase,
            currentRound: currentRound,
            targetEndDate: targetEndDate,
            isPaused: false
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: targetEndDate),
                pushType: nil
            )
            currentActivity = activity
            isActivityActive = true
        } catch {
            Self.logger.warning(
                "Failed to start Live Activity: \(String(describing: error), privacy: .public)"
            )
            currentActivity = nil
            isActivityActive = false
        }
    }

    /// Updates dynamic state on the active timer Live Activity.
    func update(
        phase: TimerActivityAttributes.Phase,
        currentRound: Int,
        targetEndDate: Date,
        isPaused: Bool
    ) {
        guard let activity = currentActivity else {
            return
        }

        let state = TimerActivityAttributes.ContentState(
            phase: phase,
            currentRound: currentRound,
            targetEndDate: targetEndDate,
            isPaused: isPaused
        )
        let staleDate = isPaused ? nil : targetEndDate

        Task {
            await activity.update(.init(state: state, staleDate: staleDate))
        }
    }

    /// Ends the active timer Live Activity immediately.
    func end() {
        endAllActivities()
    }

    private func endAllActivities() {
        let trackedActivity = currentActivity
        let activityIDsToEnd = Set(
            Activity<TimerActivityAttributes>.activities.map(\.id)
        )
        currentActivity = nil
        isActivityActive = false

        Task {
            if let trackedActivity {
                let finalContent = finalContent(for: trackedActivity.content.state)
                await trackedActivity.end(
                    finalContent,
                    dismissalPolicy: .immediate
                )
            }

            // End only activities known to exist at call time to avoid
            // racing with a newly started activity.
            for activity in Activity<TimerActivityAttributes>.activities where
                activityIDsToEnd.contains(activity.id) && activity.id != trackedActivity?.id
            {
                let finalContent = finalContent(for: activity.content.state)
                await activity.end(finalContent, dismissalPolicy: .immediate)
            }
        }
    }

    private func endAllOrphanedActivities() {
        let orphanedActivityIDs = Set(
            Activity<TimerActivityAttributes>.activities.map(\.id)
        )
        guard !orphanedActivityIDs.isEmpty else { return }

        Self.logger.notice(
            "Cleaning up \(orphanedActivityIDs.count, privacy: .public) orphaned Live Activities."
        )

        Task {
            for activity in Activity<TimerActivityAttributes>.activities where
                orphanedActivityIDs.contains(activity.id)
            {
                let finalContent = finalContent(for: activity.content.state)
                await activity.end(finalContent, dismissalPolicy: .immediate)
            }
        }
    }

    private func finalContent(
        for state: TimerActivityAttributes.ContentState
    ) -> ActivityContent<TimerActivityAttributes.ContentState> {
        let finalState = TimerActivityAttributes.ContentState(
            phase: state.phase,
            currentRound: state.currentRound,
            targetEndDate: .now,
            isPaused: state.isPaused
        )
        return ActivityContent(state: finalState, staleDate: .now)
    }
}
