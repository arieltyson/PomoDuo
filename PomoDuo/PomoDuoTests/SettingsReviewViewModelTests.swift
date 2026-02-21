import Foundation
import Testing

@testable import PomoDuo

@Suite("SettingsReviewViewModel")
@MainActor
struct SettingsReviewViewModelTests {
    @Test("Returns nil when App Store ID is missing")
    func returnsNilWithoutAppStoreID() {
        let viewModel = SettingsReviewViewModel(appStoreID: nil)

        #expect(viewModel.appStoreReviewURL == nil)
    }

    @Test("Builds a valid write-review URL for numeric App Store IDs")
    func buildsWriteReviewURLForNumericID() {
        let viewModel = SettingsReviewViewModel(appStoreID: "123456789")

        #expect(
            viewModel.appStoreReviewURL?.absoluteString
                == "https://apps.apple.com/app/id123456789?action=write-review"
        )
    }

    @Test("Normalizes prefixed IDs before generating URL")
    func normalizesPrefixedIDs() {
        let viewModel = SettingsReviewViewModel(appStoreID: "id987654321")

        #expect(
            viewModel.appStoreReviewURL?.absoluteString
                == "https://apps.apple.com/app/id987654321?action=write-review"
        )
    }

    @Test("Returns nil when value does not contain digits")
    func returnsNilForNonNumericIDs() {
        let viewModel = SettingsReviewViewModel(appStoreID: "not-configured")

        #expect(viewModel.appStoreReviewURL == nil)
    }
}
