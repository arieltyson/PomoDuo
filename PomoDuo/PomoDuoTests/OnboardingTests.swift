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
        #expect(viewModel.navigationDirection == .forward)
    }

    @Test func advanceMovesToNextStep() {
        let viewModel = OnboardingViewModel()

        let completed = viewModel.advance()

        #expect(completed == false)
        #expect(viewModel.currentStep == .focus)
        #expect(viewModel.currentIndex == 1)
        #expect(viewModel.navigationDirection == .forward)
    }

    @Test func advanceFiresHaptic() {
        let viewModel = OnboardingViewModel()

        viewModel.advance()

        #expect(viewModel.haptic.event == .phaseChange)
    }

    @Test func goBackSetsBackwardDirection() {
        let viewModel = OnboardingViewModel()
        viewModel.advance()

        viewModel.goBack()

        #expect(viewModel.currentStep == .welcome)
        #expect(viewModel.navigationDirection == .backward)
        #expect(viewModel.haptic.event == .pause)
    }

    @Test func jumpToFinalStepMovesToLast() {
        let viewModel = OnboardingViewModel()

        viewModel.jumpToFinalStep()

        #expect(viewModel.currentStep == .appBlocking)
        #expect(viewModel.isLastStep)
        #expect(viewModel.progressValue == 1)
        #expect(viewModel.navigationDirection == .forward)
    }

    @Test func notificationsPrimaryActionReflectsAuthorizationState() {
        let viewModel = OnboardingViewModel()

        _ = viewModel.advance()
        _ = viewModel.advance()
        _ = viewModel.advance()

        #expect(viewModel.currentStep == .notifications)
        #expect(
            viewModel.primaryAction(isNotificationAuthorized: false)
                == .requestNotificationPermission
        )
        #expect(
            viewModel.primaryButtonTitle(isNotificationAuthorized: false)
                == "Allow Notifications"
        )
        #expect(
            viewModel.primaryAction(isNotificationAuthorized: true)
                == .advance
        )
        #expect(
            viewModel.primaryButtonTitle(isNotificationAuthorized: true)
                == "Continue"
        )
    }

    @Test func finalStepDefaultsToTimerAndKeepsOptionalSetupPath() {
        let viewModel = OnboardingViewModel()

        viewModel.jumpToFinalStep()

        #expect(viewModel.currentStep == .appBlocking)
        #expect(
            viewModel.primaryAction(isNotificationAuthorized: false)
                == .completeOnboarding
        )
        #expect(
            viewModel.primaryButtonTitle(isNotificationAuthorized: false)
                == "Continue to Timer"
        )
        #expect(viewModel.secondaryAction == .openAppBlockingSettings)
        #expect(viewModel.secondaryButtonTitle == "Set Up")
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
        #expect(viewModel.haptic.event == .complete)
    }

    @Test func finishFiresCompletionHaptic() {
        let viewModel = OnboardingViewModel()

        viewModel.finish()

        #expect(viewModel.haptic.event == .complete)
    }
}
