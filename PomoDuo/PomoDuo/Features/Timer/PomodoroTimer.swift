import Foundation

/// An actor that manages a Pomodoro countdown using `ContinuousClock`.
///
/// Remaining time is always derived from `targetEndDate` rather than a mutable
/// decrementing counter. This keeps the timer accurate across app suspension
/// and foreground restoration.
actor PomodoroTimer {

    // MARK: - State

    private let clock = ContinuousClock()
    private let tickInterval: Duration = .seconds(1)

    private var targetEndDate: Date?
    private var totalDuration: TimeInterval = 0
    private var isPaused = false
    private var remainingAtPause: TimeInterval = 0

    private var tickTask: Task<Void, Never>?
    private var continuation: AsyncStream<TimerTick>.Continuation?

    // MARK: - Public Interface

    /// Starts a countdown for the given duration.
    /// - Parameter duration: Duration in seconds.
    /// - Returns: A stream that emits one tick per second.
    func start(duration: TimeInterval) -> AsyncStream<TimerTick> {
        stop()

        totalDuration = max(0, duration)
        isPaused = false
        remainingAtPause = 0
        targetEndDate = .now.addingTimeInterval(totalDuration)

        let (stream, continuation) = AsyncStream.makeStream(of: TimerTick.self)
        self.continuation = continuation

        tickTask = Task { [weak self] in
            await self?.runTickLoop()
        }

        return stream
    }

    /// Starts streaming ticks using an externally-provided target end date.
    ///
    /// Useful when joining or restoring an already-running session.
    func resume(targetEndDate: Date, totalDuration: TimeInterval)
        -> AsyncStream<TimerTick>
    {
        stop()

        self.targetEndDate = targetEndDate
        self.totalDuration = max(0, totalDuration)
        self.isPaused = false
        self.remainingAtPause = 0

        let (stream, continuation) = AsyncStream.makeStream(of: TimerTick.self)
        self.continuation = continuation

        tickTask = Task { [weak self] in
            await self?.runTickLoop()
        }

        return stream
    }

    /// Restores a paused timer so the UI can render it and later resume it.
    func restorePaused(
        remainingSeconds: TimeInterval,
        totalDuration: TimeInterval
    ) -> AsyncStream<TimerTick> {
        stop()

        self.totalDuration = max(0, totalDuration)
        isPaused = true
        remainingAtPause = max(0, remainingSeconds)
        targetEndDate = nil

        let (stream, continuation) = AsyncStream.makeStream(of: TimerTick.self)
        self.continuation = continuation

        continuation.yield(
            TimerTick(
                remainingSeconds: remainingAtPause,
                totalDuration: self.totalDuration,
                isPaused: true
            )
        )

        return stream
    }

    /// Pauses the timer while preserving remaining time.
    func pause() {
        guard let targetEndDate, !isPaused else { return }

        isPaused = true
        remainingAtPause = max(0, targetEndDate.timeIntervalSinceNow)
        self.targetEndDate = nil

        tickTask?.cancel()
        tickTask = nil

        continuation?.yield(
            TimerTick(
                remainingSeconds: remainingAtPause,
                totalDuration: totalDuration,
                isPaused: true
            )
        )
    }

    /// Resumes a paused timer from its preserved remaining time.
    func unpause() {
        guard isPaused else { return }

        isPaused = false
        targetEndDate = .now.addingTimeInterval(remainingAtPause)

        tickTask = Task { [weak self] in
            await self?.runTickLoop()
        }
    }

    /// Stops the timer and closes the current stream.
    func stop() {
        tickTask?.cancel()
        tickTask = nil

        continuation?.finish()
        continuation = nil

        targetEndDate = nil
        totalDuration = 0
        isPaused = false
        remainingAtPause = 0
    }

    /// Returns remaining seconds without requiring stream subscription.
    func currentRemaining() -> TimeInterval {
        if isPaused {
            return max(0, remainingAtPause)
        }

        guard let targetEndDate else { return 0 }
        return max(0, targetEndDate.timeIntervalSinceNow)
    }

    // MARK: - Private

    private func runTickLoop() async {
        while !Task.isCancelled {
            let remaining = currentRemaining()

            continuation?.yield(
                TimerTick(
                    remainingSeconds: remaining,
                    totalDuration: totalDuration,
                    isPaused: isPaused
                )
            )

            guard remaining > 0 else {
                finishCompletedRun()
                return
            }

            do {
                try await clock.sleep(for: tickInterval)
            } catch {
                return
            }
        }
    }

    private func finishCompletedRun() {
        tickTask?.cancel()
        tickTask = nil

        continuation?.finish()
        continuation = nil

        targetEndDate = nil
        isPaused = false
        remainingAtPause = 0
    }
}
