import Foundation

/// Test-friendly restriction service with call tracking and injectable errors.
actor MockRestrictionService: RestrictionService {
    private(set) var applyCallCount = 0
    private(set) var removeCallCount = 0
    private(set) var isCurrentlyRestricted = false

    var applyError: Error?
    var removeError: Error?
    var mockIsAuthorized: Bool

    init(isAuthorized: Bool = true) {
        mockIsAuthorized = isAuthorized
    }

    var isAuthorized: Bool {
        get async {
            mockIsAuthorized
        }
    }

    func applyRestrictions() async throws {
        if let applyError {
            throw applyError
        }

        applyCallCount += 1
        isCurrentlyRestricted = true
    }

    func removeRestrictions() async throws {
        if let removeError {
            throw removeError
        }

        removeCallCount += 1
        isCurrentlyRestricted = false
    }

    func reset() {
        applyCallCount = 0
        removeCallCount = 0
        isCurrentlyRestricted = false
        applyError = nil
        removeError = nil
    }

    func setApplyError(_ error: Error?) {
        applyError = error
    }

    func setRemoveError(_ error: Error?) {
        removeError = error
    }

    var applyErrorIsNil: Bool {
        applyError == nil
    }

    var removeErrorIsNil: Bool {
        removeError == nil
    }
}
