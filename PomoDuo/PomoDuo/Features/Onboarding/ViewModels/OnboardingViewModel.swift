import Foundation
import Observation
import SwiftUI

/// Drives step navigation, haptics, and animation state for onboarding.
@MainActor
@Observable
final class OnboardingViewModel {
    private(set) var currentIndex = 0

    /// The direction of the last navigation, used for transition animations.
    private(set) var navigationDirection: NavigationDirection = .forward

    /// Haptic trigger that fires on step changes and button presses.
    private(set) var haptic = HapticTrigger()

    let steps = OnboardingStep.allCases

    var currentStep: OnboardingStep {
        steps[currentIndex]
    }

    var isFirstStep: Bool {
        currentIndex == 0
    }

    var isLastStep: Bool {
        currentIndex == steps.count - 1
    }

    /// Fractional progress through the onboarding flow (0...1).
    var progressValue: Double {
        guard steps.count > 1 else { return 1 }
        return Double(currentIndex) / Double(steps.count - 1)
    }

    /// Advances to the next step. Returns `true` when onboarding is complete.
    @discardableResult
    func advance() -> Bool {
        guard !isLastStep else {
            haptic.fire(.complete)
            return true
        }

        navigationDirection = .forward
        currentIndex += 1
        haptic.fire(.phaseChange)
        return false
    }

    func goBack() {
        guard !isFirstStep else { return }
        navigationDirection = .backward
        currentIndex -= 1
        haptic.fire(.pause)
    }

    func jumpToFinalStep() {
        guard !steps.isEmpty else { return }
        navigationDirection = .forward
        currentIndex = steps.count - 1
        haptic.fire(.phaseChange)
    }

    func finish() {
        haptic.fire(.complete)
    }

    func primaryAction(
        isNotificationAuthorized: Bool
    ) -> PrimaryAction {
        switch currentStep {
        case .notifications where !isNotificationAuthorized:
            .requestNotificationPermission
        case .appBlocking:
            .completeOnboarding
        default:
            .advance
        }
    }

    func primaryButtonTitle(
        isNotificationAuthorized: Bool
    ) -> String {
        switch currentStep {
        case .notifications where isNotificationAuthorized:
            "Continue"
        default:
            currentStep.ctaTitle
        }
    }

    func primaryButtonAccessibilityHint(
        isNotificationAuthorized: Bool
    ) -> String {
        switch primaryAction(
            isNotificationAuthorized: isNotificationAuthorized
        ) {
        case .advance:
            "Moves to the next onboarding step."
        case .requestNotificationPermission:
            "Shows Apple's notification permission request."
        case .completeOnboarding:
            "Finishes onboarding and opens the focus timer."
        }
    }

    var secondaryAction: SecondaryAction {
        switch currentStep {
        case .appBlocking:
            .openAppBlockingSettings
        default:
            .skipToFinalStep
        }
    }

    var secondaryButtonTitle: String {
        switch secondaryAction {
        case .skipToFinalStep:
            "Skip"
        case .openAppBlockingSettings:
            "Set Up"
        }
    }

    var secondaryButtonSystemImage: String {
        switch secondaryAction {
        case .skipToFinalStep:
            "forward.end.alt"
        case .openAppBlockingSettings:
            "shield"
        }
    }

    var secondaryButtonAccessibilityLabel: String {
        switch secondaryAction {
        case .skipToFinalStep:
            "Skip"
        case .openAppBlockingSettings:
            "Set Up App Blocking"
        }
    }

    var secondaryButtonAccessibilityHint: String {
        switch secondaryAction {
        case .skipToFinalStep:
            "Skips to the final onboarding step."
        case .openAppBlockingSettings:
            "Opens the App Blocking screen in Settings."
        }
    }

    // MARK: - Navigation Direction

    enum PrimaryAction: Sendable, Equatable {
        case advance
        case requestNotificationPermission
        case completeOnboarding
    }

    enum SecondaryAction: Sendable, Equatable {
        case skipToFinalStep
        case openAppBlockingSettings
    }

    enum NavigationDirection: Sendable {
        case forward
        case backward
    }
}
