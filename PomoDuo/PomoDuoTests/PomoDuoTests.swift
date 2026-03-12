import Foundation
import Testing

@testable import PomoDuo

@MainActor
struct SessionStateMachineTests {

    // MARK: - Helpers

    /// Creates a session in a specific state for testing.
    private func makeSession(
        state: SessionState = .idle,
        isPaused: Bool = false,
        pausedBy: String? = nil,
        currentRound: Int = 1,
        totalRounds: Int = 4,
        duration: TimeInterval = 25 * 60,
        shortBreakDuration: TimeInterval = 5 * 60,
        longBreakDuration: TimeInterval = 15 * 60
    ) -> StudySession {
        StudySession(
            id: "test-session",
            partnerA: "alice",
            partnerB: "bob",
            state: state,
            startTime: .now,
            targetEndDate: .now.addingTimeInterval(duration),
            duration: duration,
            shortBreakDuration: shortBreakDuration,
            longBreakDuration: longBreakDuration,
            isPaused: isPaused,
            pausedBy: pausedBy,
            currentRound: currentRound,
            totalRounds: totalRounds
        )
    }

    // MARK: - Idle State

    @Test func idleToRequesting() throws {
        let session = makeSession(state: .idle)
        let result = try SessionStateMachine.apply(.requestSent, to: session)
        #expect(result.state == .requesting)
    }

    @Test func idleRejectsInvalidEvents() {
        let session = makeSession(state: .idle)
        let invalidEvents: [SessionEvent] = [
            .accepted, .declined, .focusBegan,
            .paused(by: "alice"), .resumed, .breakBegan, .completed,
        ]

        for event in invalidEvents {
            #expect(throws: SessionStateMachine.TransitionError.self) {
                try SessionStateMachine.apply(event, to: session)
            }
        }
    }

    // MARK: - Requesting State

    @Test func requestingToFocusOnAccept() throws {
        let session = makeSession(state: .requesting)
        let result = try SessionStateMachine.apply(.accepted, to: session)
        #expect(result.state == .focus)
        #expect(result.currentRound == 1)
        #expect(result.isPaused == false)
    }

    @Test func requestingToIdleOnDecline() throws {
        let session = makeSession(state: .requesting)
        let result = try SessionStateMachine.apply(.declined, to: session)
        #expect(result.state == .idle)
    }

    @Test func requestingRejectsInvalidEvents() {
        let session = makeSession(state: .requesting)
        let invalidEvents: [SessionEvent] = [
            .requestSent, .focusBegan, .paused(by: "alice"),
            .resumed, .breakBegan, .completed,
        ]

        for event in invalidEvents {
            #expect(throws: SessionStateMachine.TransitionError.self) {
                try SessionStateMachine.apply(event, to: session)
            }
        }
    }

    // MARK: - Focus State

    @Test func focusToPaused() throws {
        let session = makeSession(state: .focus)
        let result = try SessionStateMachine.apply(
            .paused(by: "alice"),
            to: session
        )
        #expect(result.state == .focus)
        #expect(result.isPaused == true)
        #expect(result.pausedBy == "alice")
    }

    @Test func focusPausedToResumed() throws {
        let session = makeSession(
            state: .focus,
            isPaused: true,
            pausedBy: "alice"
        )
        let result = try SessionStateMachine.apply(.resumed, to: session)
        #expect(result.isPaused == false)
        #expect(result.pausedBy == nil)
    }

    @Test func focusResumeWhenNotPausedThrows() {
        let session = makeSession(state: .focus, isPaused: false)
        #expect(throws: SessionStateMachine.TransitionError.self) {
            try SessionStateMachine.apply(.resumed, to: session)
        }
    }

    @Test func focusToShortBreak() throws {
        let session = makeSession(
            state: .focus,
            currentRound: 1,
            totalRounds: 4,
            shortBreakDuration: 3 * 60
        )
        let result = try SessionStateMachine.apply(.breakBegan, to: session)
        #expect(result.state == .shortBreak)
        #expect(
            abs(
                result.targetEndDate.timeIntervalSinceNow - TimeInterval(3 * 60)
            ) < 2
        )
    }

    @Test func focusToLongBreakOnFinalRound() throws {
        let session = makeSession(
            state: .focus,
            currentRound: 4,
            totalRounds: 4,
            longBreakDuration: 12 * 60
        )
        let result = try SessionStateMachine.apply(.breakBegan, to: session)
        #expect(result.state == .longBreak)
        #expect(
            abs(
                result.targetEndDate.timeIntervalSinceNow - TimeInterval(12 * 60)
            ) < 2
        )
    }

    @Test func focusBreakWhilePausedThrows() {
        let session = makeSession(
            state: .focus,
            isPaused: true,
            pausedBy: "bob"
        )
        #expect(throws: SessionStateMachine.TransitionError.self) {
            try SessionStateMachine.apply(.breakBegan, to: session)
        }
    }

    @Test func focusToCompleted() throws {
        let session = makeSession(state: .focus)
        let result = try SessionStateMachine.apply(.completed, to: session)
        #expect(result.state == .completed)
    }

    // MARK: - Short Break State

    @Test func shortBreakToFocus() throws {
        let session = makeSession(state: .shortBreak, currentRound: 2)
        let result = try SessionStateMachine.apply(.focusBegan, to: session)
        #expect(result.state == .focus)
        #expect(result.currentRound == 3)
    }

    @Test func shortBreakRejectsInvalidEvents() {
        let session = makeSession(state: .shortBreak)
        let invalidEvents: [SessionEvent] = [
            .requestSent, .accepted, .declined,
            .paused(by: "alice"), .resumed, .breakBegan, .completed,
        ]

        for event in invalidEvents {
            #expect(throws: SessionStateMachine.TransitionError.self) {
                try SessionStateMachine.apply(event, to: session)
            }
        }
    }

    // MARK: - Long Break State

    @Test func longBreakToCompleted() throws {
        let session = makeSession(state: .longBreak)
        let result = try SessionStateMachine.apply(.completed, to: session)
        #expect(result.state == .completed)
    }

    @Test func longBreakToFocusRestartsRounds() throws {
        let session = makeSession(state: .longBreak, currentRound: 4)
        let result = try SessionStateMachine.apply(.focusBegan, to: session)
        #expect(result.state == .focus)
        #expect(result.currentRound == 1)
    }

    // MARK: - Completed State

    @Test func completedRejectsAllEvents() {
        let session = makeSession(state: .completed)
        let allEvents: [SessionEvent] = [
            .requestSent, .accepted, .declined, .focusBegan,
            .paused(by: "alice"), .resumed, .breakBegan, .completed,
        ]

        for event in allEvents {
            #expect(throws: SessionStateMachine.TransitionError.self) {
                try SessionStateMachine.apply(event, to: session)
            }
        }
    }

    // MARK: - Full Session Flow

    @Test func completeSessionFlowThroughAllRounds() throws {
        var session = makeSession(state: .idle, totalRounds: 2)

        // Idle -> Requesting -> Focus
        session = try SessionStateMachine.apply(.requestSent, to: session)
        session = try SessionStateMachine.apply(.accepted, to: session)
        #expect(session.state == .focus)
        #expect(session.currentRound == 1)

        // Round 1: Focus -> Short Break -> Focus
        session = try SessionStateMachine.apply(.breakBegan, to: session)
        #expect(session.state == .shortBreak)
        session = try SessionStateMachine.apply(.focusBegan, to: session)
        #expect(session.state == .focus)
        #expect(session.currentRound == 2)

        // Round 2 (final): Focus -> Long Break -> Completed
        session = try SessionStateMachine.apply(.breakBegan, to: session)
        #expect(session.state == .longBreak)
        session = try SessionStateMachine.apply(.completed, to: session)
        #expect(session.state == .completed)
    }

    @Test func sessionFlowWithPauseAndResume() throws {
        var session = makeSession(state: .idle)
        session = try SessionStateMachine.apply(.requestSent, to: session)
        session = try SessionStateMachine.apply(.accepted, to: session)

        // Pause by alice.
        session = try SessionStateMachine.apply(
            .paused(by: "alice"),
            to: session
        )
        #expect(session.isPaused == true)
        #expect(session.pausedBy == "alice")

        // Resume.
        session = try SessionStateMachine.apply(.resumed, to: session)
        #expect(session.isPaused == false)
        #expect(session.pausedBy == nil)

        // Continue to break.
        session = try SessionStateMachine.apply(.breakBegan, to: session)
        #expect(session.state == .shortBreak)
    }
}
