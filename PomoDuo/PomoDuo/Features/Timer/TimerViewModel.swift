//
//  TimerViewModel.swift
//  PomoDuo
//
//  Created by Codex on 2/15/26.
//

import Foundation
import Observation

/// Bridges `PomodoroTimer` actor output into `@Observable` UI state.
@MainActor
@Observable
final class TimerViewModel {

    // MARK: - Observable State

    /// The latest tick emitted by the timer.
    private(set) var currentTick: TimerTick?

    /// Whether a timer is currently active. A paused timer is still considered active.
    private(set) var isRunning = false

    /// Whether the current run reached 0:00.
    private(set) var isComplete = false

    // MARK: - Dependencies

    private let timer = PomodoroTimer()
    private var tickTask: Task<Void, Never>?
    private var runID = UUID()

    // MARK: - Actions

    /// Starts a brand-new local timer run.
    func startTimer(duration: TimeInterval) {
        let runIdentifier = beginNewRun()

        tickTask = Task { [runIdentifier] in
            await timer.stop()
            let stream = await timer.start(duration: duration)
            await consume(stream: stream, for: runIdentifier)
        }
    }

    /// Aligns the local timer with a remote session that is already in progress.
    func syncToRemote(targetEndDate: Date, totalDuration: TimeInterval) {
        let runIdentifier = beginNewRun()

        tickTask = Task { [runIdentifier] in
            await timer.stop()
            let stream = await timer.resume(
                targetEndDate: targetEndDate,
                totalDuration: totalDuration
            )
            await consume(stream: stream, for: runIdentifier)
        }
    }

    /// Pauses the active timer.
    func pause() {
        Task { await timer.pause() }
    }

    /// Unpauses a paused timer.
    func unpause() {
        Task { await timer.unpause() }
    }

    /// Stops the timer and clears all UI state.
    func stop() {
        tickTask?.cancel()
        tickTask = nil

        Task { await timer.stop() }

        currentTick = nil
        isRunning = false
        isComplete = false
        runID = UUID()
    }

    // MARK: - Private

    @discardableResult
    private func beginNewRun() -> UUID {
        tickTask?.cancel()
        tickTask = nil

        currentTick = nil
        isRunning = true
        isComplete = false
        runID = UUID()
        return runID
    }

    private func consume(stream: AsyncStream<TimerTick>, for id: UUID) async {
        for await tick in stream {
            guard id == runID else { return }
            currentTick = tick
        }

        guard id == runID else { return }
        isRunning = false
        isComplete = true
    }
}
