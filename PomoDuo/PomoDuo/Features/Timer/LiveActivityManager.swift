//
//  LiveActivityManager.swift
//  PomoDuo
//
//  Created by Codex on 2/15/26.
//

import ActivityKit
import Foundation
import Observation

/// Owns the lifecycle of the timer Live Activity.
@MainActor
@Observable
final class LiveActivityManager {
    /// Whether a timer Live Activity is currently active.
    private(set) var isActivityActive = false

    private var currentActivity: Activity<TimerActivityAttributes>?

    /// Starts a new timer Live Activity.
    /// Any previous activity is ended immediately first.
    func start(
        phase: TimerActivityAttributes.Phase,
        currentRound: Int,
        totalRounds: Int,
        targetEndDate: Date
    ) {
        endImmediately()

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
        endImmediately()
    }

    private func endImmediately() {
        guard let activity = currentActivity else {
            return
        }

        currentActivity = nil
        isActivityActive = false

        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
