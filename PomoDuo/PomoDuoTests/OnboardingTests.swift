import Foundation
import Testing

@testable import PomoDuo

@MainActor
struct OnboardingManagerTests {
    @Test func defaultsToNotCompleted() {
        guard let defaults = makeIsolatedDefaults(named: #function) else {
            #expect(Bool(false), "Unable to create isolated defaults")
            return
        }

        let manager = OnboardingManager(userDefaults: defaults)
        #expect(manager.hasCompletedOnboarding == false)
    }

    @Test func completeOnboardingPersistsValue() {
        guard let defaults = makeIsolatedDefaults(named: #function) else {
            #expect(Bool(false), "Unable to create isolated defaults")
            return
        }

        let manager = OnboardingManager(userDefaults: defaults)
        manager.completeOnboarding()

        #expect(manager.hasCompletedOnboarding)
        #expect(defaults.bool(forKey: OnboardingManager.storageKey))
    }

    @Test func readsPersistedCompletionFlag() {
        guard let defaults = makeIsolatedDefaults(named: #function) else {
            #expect(Bool(false), "Unable to create isolated defaults")
            return
        }

        defaults.set(true, forKey: OnboardingManager.storageKey)

        let manager = OnboardingManager(userDefaults: defaults)
        #expect(manager.hasCompletedOnboarding)
    }

    private func makeIsolatedDefaults(named testName: String) -> UserDefaults? {
        let suiteName = "com.pomoduo.tests.onboarding.\(testName)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return nil
        }

        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

@MainActor
struct OnboardingViewModelTests {
    @Test func startsAtWelcomeStep() {
        let viewModel = OnboardingViewModel()

        #expect(viewModel.currentIndex == 0)
        #expect(viewModel.currentStep == .welcome)
        #expect(viewModel.isFirstStep)
        #expect(viewModel.isLastStep == false)
        #expect(viewModel.progressValue == 0)
    }

    @Test func advanceMovesToNextStep() {
        let viewModel = OnboardingViewModel()

        let completed = viewModel.advance()

        #expect(completed == false)
        #expect(viewModel.currentStep == .focus)
        #expect(viewModel.currentIndex == 1)
    }

    @Test func jumpToFinalStepMovesToLast() {
        let viewModel = OnboardingViewModel()

        viewModel.jumpToFinalStep()

        #expect(viewModel.currentStep == .appBlocking)
        #expect(viewModel.isLastStep)
        #expect(viewModel.progressValue == 1)
    }

    @Test func backDoesNotMoveBeforeFirstStep() {
        let viewModel = OnboardingViewModel()

        viewModel.goBack()

        #expect(viewModel.currentStep == .welcome)
        #expect(viewModel.currentIndex == 0)
    }

    @Test func advanceReturnsTrueAtLastStep() {
        let viewModel = OnboardingViewModel()
        viewModel.jumpToFinalStep()

        let completed = viewModel.advance()

        #expect(completed)
        #expect(viewModel.currentStep == .appBlocking)
        #expect(viewModel.currentIndex == OnboardingStep.allCases.count - 1)
    }
}
