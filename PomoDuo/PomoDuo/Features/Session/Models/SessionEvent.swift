import Foundation

/// An explicit event that triggers a state machine transition.
/// Every mutation to a `StudySession` should flow through one of these events.
enum SessionEvent: Sendable, Equatable {
    /// Partner A requests a new session.
    case requestSent
    /// Partner B accepts the session request.
    case accepted
    /// Partner B declines or the request times out.
    case declined
    /// A focus period begins. Timer starts and restrictions apply.
    case focusBegan
    /// A user pauses the session and identifies who initiated the pause.
    case paused(by: String)
    /// The session resumes after a pause.
    case resumed
    /// A break period begins. Short vs long is determined by session round data.
    case breakBegan
    /// All rounds are complete and the session ends.
    case completed
}
