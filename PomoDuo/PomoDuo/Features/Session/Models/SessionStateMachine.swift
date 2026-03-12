import Foundation

/// A pure, stateless engine that computes the next `StudySession` for a given event.
/// Invalid transitions throw `TransitionError` rather than silently failing.
enum SessionStateMachine {

    /// Describes an invalid state machine transition.
    enum TransitionError: Error, Equatable, CustomStringConvertible {
        case invalidTransition(from: SessionState, event: String)

        var description: String {
            switch self {
            case .invalidTransition(let from, let event):
                "Invalid transition: cannot apply '\(event)' from '\(from.rawValue)' state"
            }
        }
    }

    /// Computes the next session state by applying an event to the current session.
    /// - Parameters:
    ///   - event: The event to apply.
    ///   - session: The current session state.
    /// - Returns: A new `StudySession` with the transition applied.
    /// - Throws: `TransitionError` if the event is not valid for the current state.
    static func apply(_ event: SessionEvent, to session: StudySession) throws
        -> StudySession
    {
        var next = session

        switch (session.state, event) {

        // MARK: - Idle

        case (.idle, .requestSent):
            next.state = .requesting

        // MARK: - Requesting

        case (.requesting, .accepted):
            next.state = .focus
            next.startTime = .now
            next.targetEndDate = .now.addingTimeInterval(session.duration)
            next.isPaused = false
            next.pausedBy = nil
            next.currentRound = 1

        case (.requesting, .declined):
            next.state = .idle

        // MARK: - Focus

        case (.focus, let .paused(userID)):
            next.state = .focus
            next.isPaused = true
            next.pausedBy = userID

        case (.focus, .resumed):
            guard session.isPaused else {
                throw TransitionError.invalidTransition(
                    from: session.state,
                    event: "resumed (not paused)"
                )
            }

            next.isPaused = false
            next.pausedBy = nil
            if session.targetEndDate < .now {
                next.targetEndDate = .now.addingTimeInterval(session.duration)
            }

        case (.focus, .breakBegan):
            guard !session.isPaused else {
                throw TransitionError.invalidTransition(
                    from: session.state,
                    event: "breakBegan (still paused)"
                )
            }
            let isLongBreak = session.currentRound >= session.totalRounds
            let breakDuration =
                isLongBreak
                ? session.longBreakDuration
                : session.shortBreakDuration

            next.state = isLongBreak ? .longBreak : .shortBreak
            next.startTime = .now
            next.targetEndDate = .now.addingTimeInterval(breakDuration)
            next.isPaused = false
            next.pausedBy = nil

        case (.focus, .completed):
            next.state = .completed

        // MARK: - Short Break

        case (.shortBreak, .focusBegan):
            next.state = .focus
            next.startTime = .now
            next.targetEndDate = .now.addingTimeInterval(session.duration)
            next.currentRound = session.currentRound + 1
            next.isPaused = false
            next.pausedBy = nil

        // MARK: - Long Break

        case (.longBreak, .completed):
            next.state = .completed

        case (.longBreak, .focusBegan):
            // Allow restarting rounds after a long break.
            next.state = .focus
            next.startTime = .now
            next.targetEndDate = .now.addingTimeInterval(session.duration)
            next.currentRound = 1
            next.isPaused = false
            next.pausedBy = nil

        // MARK: - Invalid

        default:
            throw TransitionError.invalidTransition(
                from: session.state,
                event: "\(event)"
            )
        }

        return next
    }
}
