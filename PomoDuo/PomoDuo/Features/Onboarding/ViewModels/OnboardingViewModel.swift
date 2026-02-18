import Foundation
import Observation

/// Drives step state and navigation for onboarding.
@MainActor
@Observable
final class OnboardingViewModel {
    private(set) var currentIndex = 0

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

    var progressValue: Double {
        guard steps.count > 1 else { return 1 }
        return Double(currentIndex) / Double(steps.count - 1)
    }

    /// Advances to the next step. Returns `true` when onboarding is complete.
    @discardableResult
    func advance() -> Bool {
        guard !isLastStep else {
            return true
        }

        currentIndex += 1
        return false
    }

    func goBack() {
        guard !isFirstStep else { return }
        currentIndex -= 1
    }

    func jumpToFinalStep() {
        guard !steps.isEmpty else { return }
        currentIndex = steps.count - 1
    }
}
