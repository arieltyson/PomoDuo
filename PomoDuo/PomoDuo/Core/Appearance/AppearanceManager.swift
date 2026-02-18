import Foundation
import Observation
import SwiftUI

/// Stores and exposes the app's appearance preference.
@MainActor
@Observable
final class AppearanceManager {
    static let storageKey = "com.pomoduo.appearance.preference"

    var selectedAppearance: AppAppearance {
        didSet {
            userDefaults.set(
                selectedAppearance.rawValue,
                forKey: Self.storageKey
            )
        }
    }

    var preferredColorScheme: ColorScheme? {
        selectedAppearance.preferredColorScheme
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        if let rawValue = userDefaults.string(forKey: Self.storageKey),
            let persisted = AppAppearance(rawValue: rawValue)
        {
            selectedAppearance = persisted
        } else {
            selectedAppearance = .system
        }
    }
}
