import Foundation
import Testing

@testable import PomoDuo

@MainActor
struct TimerActivityDisplayStateTests {
    private let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func clampsOversizedDurationsToExpectedMaximums() {
        let cases: [(TimerActivityAttributes.Phase, TimeInterval)] = [
            (.focus, 60 * 60),
            (.shortBreak, 10 * 60),
            (.longBreak, 30 * 60),
        ]

        for (phase, expectedMaximum) in cases {
            let state = TimerActivityAttributes.ContentState(
                phase: phase,
                currentRound: 1,
                targetEndDate: referenceDate.addingTimeInterval(expectedMaximum * 2),
                isPaused: false,
                phaseDuration: expectedMaximum * 2
            )

            let sanitized = state.sanitizedForDisplay(referenceDate: referenceDate)

            #expect(sanitized.phaseDuration == expectedMaximum)
            #expect(
                sanitized.targetEndDate
                    == referenceDate.addingTimeInterval(expectedMaximum)
            )
        }
    }

    @Test func clampsCountdownToCurrentPhaseDurationWhenDeadlineOvershoots() {
        let state = TimerActivityAttributes.ContentState(
            phase: .focus,
            currentRound: 1,
            targetEndDate: referenceDate.addingTimeInterval(2 * 60 * 60 + 6 * 60),
            isPaused: false,
            phaseDuration: 25 * 60
        )

        let sanitized = state.sanitizedForDisplay(referenceDate: referenceDate)

        #expect(sanitized.phaseDuration == 25 * 60)
        #expect(
            sanitized.targetEndDate
                == referenceDate.addingTimeInterval(25 * 60)
        )
    }

    @Test func expiredFocusAndBreakStatesCollapseCountdownRangeToZero() {
        let cases: [(TimerActivityAttributes.Phase, TimeInterval)] = [
            (.focus, 25 * 60),
            (.shortBreak, 5 * 60),
            (.longBreak, 15 * 60),
        ]

        for (phase, phaseDuration) in cases {
            let state = TimerActivityAttributes.ContentState(
                phase: phase,
                currentRound: 1,
                targetEndDate: referenceDate.addingTimeInterval(-5),
                isPaused: false,
                phaseDuration: phaseDuration
            )

            let range = state.countdownRange(referenceDate: referenceDate)

            #expect(state.remainingSecondsForDisplay(asOf: referenceDate) == 0)
            #expect(range.lowerBound == referenceDate)
            #expect(range.upperBound == referenceDate)
        }
    }

    @Test func validPausedStatesRemainStableDuringSanitization() {
        let state = TimerActivityAttributes.ContentState(
            phase: .focus,
            currentRound: 2,
            targetEndDate: referenceDate.addingTimeInterval(14 * 60 + 46),
            isPaused: true,
            phaseDuration: 25 * 60,
            pausedRemainingSeconds: 14 * 60 + 46
        )

        let sanitized = state.sanitizedForDisplay(referenceDate: referenceDate)

        #expect(sanitized == state)
        #expect(state.hasInvalidTimingInvariants(asOf: referenceDate) == false)
    }

    @Test func pausedStatesClampRemainingWithoutShiftingTargetEndDate() {
        let targetEndDate = referenceDate.addingTimeInterval(8 * 60)
        let state = TimerActivityAttributes.ContentState(
            phase: .shortBreak,
            currentRound: 1,
            targetEndDate: targetEndDate,
            isPaused: true,
            phaseDuration: 5 * 60,
            pausedRemainingSeconds: 8 * 60
        )

        let sanitized = state.sanitizedForDisplay(referenceDate: referenceDate)

        #expect(sanitized.targetEndDate == targetEndDate)
        #expect(sanitized.pausedRemainingSeconds == 5 * 60)
        #expect(state.hasInvalidTimingInvariants(asOf: referenceDate))
    }
}
