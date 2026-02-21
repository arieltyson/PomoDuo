import Foundation
import Observation

/// View model for resolving the best rating destination from app metadata.
@MainActor
@Observable
final class SettingsReviewViewModel {
    /// Info.plist key that stores the App Store numeric app identifier.
    static let appStoreIDInfoDictionaryKey = "APP_STORE_ID"

    private let appStoreID: String?

    init(
        appStoreID: String? =
            Bundle.main.object(
                forInfoDictionaryKey: SettingsReviewViewModel
                    .appStoreIDInfoDictionaryKey
            ) as? String
    ) {
        self.appStoreID = appStoreID
    }

    /// Direct App Store write-review URL when an App Store ID is available.
    var appStoreReviewURL: URL? {
        guard let normalizedAppStoreID else {
            return nil
        }

        return URL(
            string:
                "https://apps.apple.com/app/id\(normalizedAppStoreID)?action=write-review"
        )
    }

    private var normalizedAppStoreID: String? {
        guard let appStoreID else {
            return nil
        }

        let trimmedID = appStoreID.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmedID.isEmpty else {
            return nil
        }

        let numericOnlyID = String(trimmedID.filter(\.isNumber))
        guard !numericOnlyID.isEmpty else {
            return nil
        }

        return numericOnlyID
    }
}
