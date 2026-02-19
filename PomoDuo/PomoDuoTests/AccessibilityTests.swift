import Foundation
import SwiftUI
import Testing

@testable import PomoDuo

@MainActor
struct AccessibilityAnnouncerTests {
    @Test func announceStartDoesNotThrow() {
        AccessibilityAnnouncer.announceStart(round: 1, totalRounds: 4)
    }

    @Test func announcePauseDoesNotThrow() {
        AccessibilityAnnouncer.announcePause()
    }

    @Test func announceResumeDoesNotThrow() {
        AccessibilityAnnouncer.announceResume()
    }

    @Test func announceRoundCompleteDoesNotThrow() {
        AccessibilityAnnouncer.announceRoundComplete()
    }

    @Test func announceShortBreakDoesNotThrow() {
        AccessibilityAnnouncer.announceBreakStarted(isLong: false)
    }

    @Test func announceLongBreakDoesNotThrow() {
        AccessibilityAnnouncer.announceBreakStarted(isLong: true)
    }

    @Test func announceFocusResumedDoesNotThrow() {
        AccessibilityAnnouncer.announceFocusResumed(round: 2, totalRounds: 4)
    }

    @Test func announceStopDoesNotThrow() {
        AccessibilityAnnouncer.announceStop()
    }
}

struct CircularProgressAccessibilityTests {
    func accessibilityDescription(
        isBreak: Bool,
        isPaused: Bool,
        remainingProgress: Double
    ) -> String {
        let timerType = isBreak ? "Break timer" : "Focus timer"

        if isPaused {
            return "\(timerType), paused"
        }

        let percentComplete = Int((1 - remainingProgress) * 100)
        return "\(timerType), \(percentComplete) percent complete"
    }

    @Test func focusTimerLabel() {
        let label = accessibilityDescription(
            isBreak: false,
            isPaused: false,
            remainingProgress: 0.75
        )
        #expect(label == "Focus timer, 25 percent complete")
    }

    @Test func breakTimerLabel() {
        let label = accessibilityDescription(
            isBreak: true,
            isPaused: false,
            remainingProgress: 0.5
        )
        #expect(label == "Break timer, 50 percent complete")
    }

    @Test func pausedFocusTimerLabel() {
        let label = accessibilityDescription(
            isBreak: false,
            isPaused: true,
            remainingProgress: 0.75
        )
        #expect(label == "Focus timer, paused")
    }

    @Test func pausedBreakTimerLabel() {
        let label = accessibilityDescription(
            isBreak: true,
            isPaused: true,
            remainingProgress: 0.5
        )
        #expect(label == "Break timer, paused")
    }

    @Test func zeroProgressLabel() {
        let label = accessibilityDescription(
            isBreak: false,
            isPaused: false,
            remainingProgress: 0.0
        )
        #expect(label == "Focus timer, 100 percent complete")
    }

    @Test func fullProgressLabel() {
        let label = accessibilityDescription(
            isBreak: false,
            isPaused: false,
            remainingProgress: 1.0
        )
        #expect(label == "Focus timer, 0 percent complete")
    }
}

struct ReducedMotionModifierTests {
    @Test @MainActor func modifierInitializesWithAnimations() {
        let standard = Animation.easeInOut(duration: 0.7)
        let reduced = Animation.default.speed(2)
        let modifier = ReducedMotionModifier(
            value: 0.5,
            standardAnimation: standard,
            reducedAnimation: reduced
        )
        #expect(modifier.value == 0.5)
    }
}
