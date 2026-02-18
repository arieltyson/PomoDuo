import Foundation
import Observation

/// Persists whether the user has completed first-launch onboarding.
@MainActor
@Observable
final class OnboardingManager {
    static let storageKey = "com.pomoduo.onboarding.completed"

    var hasCompletedOnboarding: Bool {
        didSet {
            userDefaults.set(hasCompletedOnboarding, forKey: Self.storageKey)
        }
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        hasCompletedOnboarding = userDefaults.bool(forKey: Self.storageKey)
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
    }
}
