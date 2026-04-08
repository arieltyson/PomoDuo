import Foundation
import Testing

@testable import PomoDuo

@MainActor
struct TimerActivityPhaseTests {
    @Test func focusPhaseProperties() {
        let phase = TimerActivityAttributes.Phase.focus
        #expect(phase.label == "Focus")
        #expect(phase.systemImage == "brain.head.profile")
        #expect(phase.isBreak == false)
    }

    @Test func shortBreakPhaseProperties() {
        let phase = TimerActivityAttributes.Phase.shortBreak
        #expect(phase.label == "Short Break")
        #expect(phase.systemImage == "cup.and.saucer.fill")
        #expect(phase.isBreak)
    }

    @Test func longBreakPhaseProperties() {
        let phase = TimerActivityAttributes.Phase.longBreak
        #expect(phase.label == "Long Break")
        #expect(phase.systemImage == "figure.walk")
        #expect(phase.isBreak)
    }

    @Test func phaseRawValueRoundTrip() throws {
        for phase in [
            TimerActivityAttributes.Phase.focus, .shortBreak, .longBreak,
        ] {
            let data = try JSONEncoder().encode(phase)
            let decoded = try JSONDecoder().decode(
                TimerActivityAttributes.Phase.self,
                from: data
            )
            #expect(decoded == phase)
        }
    }

    @Test func contentStateCodableAndHashable() throws {
        let state = TimerActivityAttributes.ContentState(
            phase: .focus,
            currentRound: 2,
            targetEndDate: .init(timeIntervalSince1970: 1_700_000_000),
            isPaused: false,
            phaseDuration: 25 * 60
        )

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(
            TimerActivityAttributes.ContentState.self,
            from: data
        )

        #expect(decoded == state)
        #expect(decoded.hashValue == state.hashValue)
    }

    @Test func pausedStateDiffersFromRunningState() {
        let date = Date.now

        let running = TimerActivityAttributes.ContentState(
            phase: .focus,
            currentRound: 1,
            targetEndDate: date,
            isPaused: false,
            phaseDuration: 25 * 60
        )

        let paused = TimerActivityAttributes.ContentState(
            phase: .focus,
            currentRound: 1,
            targetEndDate: date,
            isPaused: true,
            phaseDuration: 25 * 60
        )

        #expect(running != paused)
    }
}

@MainActor
struct CountdownRangeTests {
    @Test func focusCountdownRangeFitsMinuteSecondFormat() {
        // The Lock Screen countdown uses showsHours: false, so the maximum
        // rendered value must fit MM:SS format (≤ 99:59). The product's
        // maximum focus duration is 60 minutes (3600 s).
        let maxFocusDuration: TimeInterval = TimerActivityAttributes.Phase.focus
            .maximumExpectedDuration
        #expect(maxFocusDuration <= 99 * 60 + 59)
    }

    @Test func allPhaseDurationsFitMinuteSecondFormat() {
        let phases: [TimerActivityAttributes.Phase] = [
            .focus, .shortBreak, .longBreak,
        ]
        for phase in phases {
            #expect(
                phase.maximumExpectedDuration <= 99 * 60 + 59,
                "\(phase.label) exceeds MM:SS display range"
            )
        }
    }

    @Test func countdownRangeSpanMatchesPhaseDuration() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let duration: TimeInterval = 60 * 60
        let state = TimerActivityAttributes.ContentState(
            phase: .focus,
            currentRound: 1,
            targetEndDate: now.addingTimeInterval(duration),
            isPaused: false,
            phaseDuration: duration
        )

        let range = state.countdownRange(referenceDate: now)
        let span = range.upperBound.timeIntervalSince(range.lowerBound)
        #expect(span == duration)
    }
}

@MainActor
struct LiveActivityManagerTests {
    @Test func initialStateIsInactive() {
        let manager = LiveActivityManager()
        #expect(manager.isActivityActive == false)
    }

    @Test func endWithoutActiveActivityIsSafe() {
        let manager = LiveActivityManager()
        manager.end()
        #expect(manager.isActivityActive == false)
    }

    @Test func updateWithoutActiveActivityIsSafe() {
        let manager = LiveActivityManager()

        manager.update(
            phase: .focus,
            currentRound: 1,
            targetEndDate: .now.addingTimeInterval(60),
            isPaused: false,
            phaseDuration: 25 * 60
        )

        #expect(manager.isActivityActive == false)
    }
}
