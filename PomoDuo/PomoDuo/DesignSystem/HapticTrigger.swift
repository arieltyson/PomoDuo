import SwiftUI

/// A small state value used as the `.sensoryFeedback` trigger in SwiftUI.
///
/// `fireCount` increments on every call to `fire(_:)` so repeated events
/// still produce haptics when the same event type occurs back-to-back.
struct HapticTrigger: Equatable, Sendable {

    /// Timer events that should produce tactile feedback.
    enum Event: Sendable, Equatable {
        case start
        case pause
        case resume
        case complete
        case phaseChange
        case stop
    }

    /// Internal semantic mapping used by tests and feedback conversion.
    enum FeedbackStyle: Sendable, Equatable {
        case impactLight
        case impactSoft
        case impactMedium
        case impactHeavy
        case impactRigid
        case success
    }

    /// The most recently fired event.
    private(set) var event: Event?

    /// Incremented for every event so two consecutive identical events are
    /// still treated as distinct trigger values by SwiftUI.
    private var fireCount = 0

    /// Semantic style derived from the current event.
    var style: FeedbackStyle {
        switch event {
        case .start:
            .impactMedium
        case .pause:
            .impactSoft
        case .resume:
            .impactMedium
        case .complete:
            .success
        case .phaseChange:
            .impactHeavy
        case .stop:
            .impactRigid
        case .none:
            .impactLight
        }
    }

    /// SwiftUI feedback style used by `.sensoryFeedback`.
    var feedback: SensoryFeedback {
        switch style {
        case .impactLight:
            .impact(weight: .light)
        case .impactSoft:
            .impact(flexibility: .soft)
        case .impactMedium:
            .impact(weight: .medium)
        case .impactHeavy:
            .impact(weight: .heavy)
        case .impactRigid:
            .impact(flexibility: .rigid)
        case .success:
            .success
        }
    }

    /// Registers a new event and updates the trigger value.
    mutating func fire(_ event: Event) {
        self.event = event
        fireCount += 1
    }
}
