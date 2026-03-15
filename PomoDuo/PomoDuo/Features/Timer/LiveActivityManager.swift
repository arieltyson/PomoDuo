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

    /// Grace period after the target date before auto-end cleanup fires.
    private static let autoEndGracePeriod: TimeInterval = 2
    /// Minimum cadence for cosmetic-only lock-screen updates.
    private static let cosmeticUpdateMinimumInterval: TimeInterval = 2

    /// Whether a timer Live Activity is currently active.
    private(set) var isActivityActive = false

    private var currentActivity: Activity<TimerActivityAttributes>?
    private var autoEndTask: Task<Void, Never>?
    private var autoEndScheduleID: UInt64 = 0
    private var lastCosmeticUpdateDate: Date?
    private var lastDispatchedState: TimerActivityAttributes.ContentState?

    init() {
        endAllOrphanedActivities()
    }

    /// Starts a new timer Live Activity.
    /// Any previous activity is ended immediately first.
    func start(
        phase: TimerActivityAttributes.Phase,
        currentRound: Int,
        totalRounds: Int,
        targetEndDate: Date,
        phaseDuration: TimeInterval
    ) {
        endAllActivities()

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            isActivityActive = false
            return
        }

        let attributes = TimerActivityAttributes(totalRounds: totalRounds)
        let rawState = TimerActivityAttributes.ContentState(
            phase: phase,
            currentRound: currentRound,
            targetEndDate: targetEndDate,
            isPaused: false,
            phaseDuration: phaseDuration
        )
        let state = sanitize(rawState)

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: state.targetEndDate),
                pushType: nil
            )
            currentActivity = activity
            isActivityActive = true
            lastDispatchedState = state
            lastCosmeticUpdateDate = nil
            scheduleAutoEnd(at: state.targetEndDate)
        } catch {
            Self.logger.warning(
                "Failed to start Live Activity: \(String(describing: error), privacy: .public)"
            )
            currentActivity = nil
            isActivityActive = false
            lastDispatchedState = nil
            lastCosmeticUpdateDate = nil
            cancelAutoEnd()
        }
    }

    /// Updates dynamic state on the active timer Live Activity.
    func update(
        phase: TimerActivityAttributes.Phase,
        currentRound: Int,
        targetEndDate: Date,
        isPaused: Bool,
        phaseDuration: TimeInterval,
        pausedRemainingSeconds: TimeInterval = 0
    ) {
        guard let activity = currentActivity else {
            return
        }
        let previousState = lastDispatchedState ?? activity.content.state
        let isStateChanging = previousState.phase != phase
            || previousState.currentRound != currentRound
            || previousState.isPaused != isPaused
        let now = Date.now

        if !isStateChanging,
            let lastCosmeticUpdateDate,
            now.timeIntervalSince(lastCosmeticUpdateDate)
                < Self.cosmeticUpdateMinimumInterval
        {
            return
        }

        let rawState = TimerActivityAttributes.ContentState(
            phase: phase,
            currentRound: currentRound,
            targetEndDate: targetEndDate,
            isPaused: isPaused,
            phaseDuration: phaseDuration,
            pausedRemainingSeconds: pausedRemainingSeconds
        )
        let state = sanitize(rawState)
        let staleDate = isPaused ? nil : state.targetEndDate

        Task {
            await activity.update(.init(state: state, staleDate: staleDate))
        }
        lastDispatchedState = state
        lastCosmeticUpdateDate = now

        if isPaused {
            cancelAutoEnd()
        } else {
            scheduleAutoEnd(at: state.targetEndDate)
        }
    }

    /// Ends the active timer Live Activity immediately.
    func end() {
        endAllActivities()
    }

    // MARK: - Auto-End

    /// Schedules an automatic cleanup if timer completion is never observed
    /// by an active view (for example on Lock Screen or another tab).
    private func scheduleAutoEnd(at targetEndDate: Date) {
        cancelAutoEnd()
        let scheduleID = autoEndScheduleID
        let delaySeconds =
            max(0, targetEndDate.timeIntervalSinceNow) + Self.autoEndGracePeriod

        autoEndTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delaySeconds))
            guard let self else { return }
            self.handleAutoEndTrigger(scheduleID: scheduleID)
        }
    }

    private func handleAutoEndTrigger(scheduleID: UInt64) {
        guard scheduleID == autoEndScheduleID else { return }
        guard let activity = currentActivity else { return }
        guard
            Date.now
                >= activity.content.state.targetEndDate.addingTimeInterval(
                    Self.autoEndGracePeriod
                )
        else { return }

        Self.logger.notice("Auto-ending stale timer Live Activity.")
        endAllActivities()
    }

    private func cancelAutoEnd() {
        autoEndTask?.cancel()
        autoEndTask = nil
        autoEndScheduleID &+= 1
    }

    // MARK: - Activity Lifecycle

    private func endAllActivities() {
        cancelAutoEnd()

        let trackedActivity = currentActivity
        let activityIDsToEnd = Set(
            Activity<TimerActivityAttributes>.activities.map(\.id)
        )
        currentActivity = nil
        isActivityActive = false
        lastDispatchedState = nil
        lastCosmeticUpdateDate = nil

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
            isPaused: false,
            phaseDuration: state.phaseDuration,
            pulsePhase: false
        )
        return ActivityContent(state: finalState, staleDate: nil)
    }

    private func sanitize(
        _ rawState: TimerActivityAttributes.ContentState
    ) -> TimerActivityAttributes.ContentState {
        let referenceDate = Date.now
        let sanitizedState = rawState.sanitizedForDisplay(
            referenceDate: referenceDate
        )
        guard sanitizedState != rawState else {
            return rawState
        }

        let hasInvalidTimingInvariants = rawState.hasInvalidTimingInvariants(
            asOf: referenceDate
        )

        if hasInvalidTimingInvariants {
            assertionFailure("Invalid Live Activity timer state was sanitized.")
        }

        let rawRemainingSeconds =
            rawState.isPaused
            ? rawState.pausedRemainingSeconds
            : rawState.targetEndDate.timeIntervalSince(referenceDate)
        let sanitizedRemainingSeconds =
            sanitizedState.isPaused
            ? sanitizedState.pausedRemainingSeconds
            : sanitizedState.targetEndDate.timeIntervalSince(referenceDate)

        if hasInvalidTimingInvariants {
            Self.logger.error(
                """
                Sanitized invalid Live Activity state. phase=\(rawState.phase.rawValue, privacy: .public) \
                round=\(rawState.currentRound, privacy: .public) \
                rawRemaining=\(rawRemainingSeconds, privacy: .public) \
                rawDuration=\(rawState.phaseDuration, privacy: .public) \
                sanitizedRemaining=\(sanitizedRemainingSeconds, privacy: .public) \
                sanitizedDuration=\(sanitizedState.phaseDuration, privacy: .public)
                """
            )
        } else {
            Self.logger.notice(
                """
                Normalized Live Activity state. phase=\(rawState.phase.rawValue, privacy: .public) \
                round=\(rawState.currentRound, privacy: .public) \
                rawRemaining=\(rawRemainingSeconds, privacy: .public) \
                rawDuration=\(rawState.phaseDuration, privacy: .public) \
                normalizedRemaining=\(sanitizedRemainingSeconds, privacy: .public) \
                normalizedDuration=\(sanitizedState.phaseDuration, privacy: .public)
                """
            )
        }

        return sanitizedState
    }
}
