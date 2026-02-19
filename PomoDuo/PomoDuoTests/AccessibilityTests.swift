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
    @Test func focusTimerLabel() {
        let isBreak = false
        let remainingProgress = 0.75
        let timerType = isBreak ? "Break timer" : "Focus timer"
        let percentComplete = Int((1 - remainingProgress) * 100)
        let label = "\(timerType), \(percentComplete) percent complete"
        #expect(label == "Focus timer, 25 percent complete")
    }

    @Test func breakTimerLabel() {
        let isBreak = true
        let remainingProgress = 0.5
        let timerType = isBreak ? "Break timer" : "Focus timer"
        let percentComplete = Int((1 - remainingProgress) * 100)
        let label = "\(timerType), \(percentComplete) percent complete"
        #expect(label == "Break timer, 50 percent complete")
    }

    @Test func pausedTimerLabel() {
        let timerType = "Focus timer"
        let label = "\(timerType), paused"
        #expect(label == "Focus timer, paused")
    }

    @Test func zeroProgressLabel() {
        let remainingProgress = 0.0
        let percentComplete = Int((1 - remainingProgress) * 100)
        #expect(percentComplete == 100)
    }

    @Test func fullProgressLabel() {
        let remainingProgress = 1.0
        let percentComplete = Int((1 - remainingProgress) * 100)
        #expect(percentComplete == 0)
    }
}

struct ReducedMotionModifierTests {
    @Test func modifierInitializesWithAnimations() {
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
