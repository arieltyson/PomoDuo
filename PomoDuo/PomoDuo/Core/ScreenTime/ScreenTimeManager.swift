import FamilyControls
import Foundation
import ManagedSettings
import Observation

/// Coordinates Screen Time authorization and selected apps/categories to block.
@MainActor
@Observable
final class ScreenTimeManager {
    private(set) var authorizationStatus: AuthorizationStatus
    private(set) var authorizationError: String?
    private(set) var isRequestingAuthorization = false

    /// The user's current picker selection.
    ///
    /// `includeEntireCategory: true` keeps category selections expanded so a
    /// later partial deselect can be translated into category exceptions.
    var activitySelection = FamilyActivitySelection(includeEntireCategory: true) {
        didSet {
            persistSelection()
        }
    }

    /// Category tokens the shield policy should enforce.
    ///
    /// This can intentionally differ from ``activitySelection.categoryTokens``.
    /// The picker has no native way to express "block this category except
    /// these apps", so partial category edits are preserved here for
    /// Managed Settings while ``activitySelection`` stays faithful to what the
    /// picker shows.
    private(set) var shieldedCategoryTokens: Set<ActivityCategoryToken> = [] {
        didSet {
            persistShieldedCategoryTokens()
        }
    }

    /// Apps the user explicitly allows inside an otherwise blocked category.
    private(set) var categoryExceptions: Set<ApplicationToken> = [] {
        didSet {
            persistCategoryExceptions()
        }
    }

    /// Web domains the user explicitly allows inside an otherwise blocked
    /// category.
    private(set) var webDomainCategoryExceptions: Set<WebDomainToken> = [] {
        didSet {
            persistWebDomainCategoryExceptions()
        }
    }

    /// Apple's documented maximum exception count for a category policy.
    static let categoryExceptionsLimit = 50

    var isAuthorized: Bool {
        if authorizationStatus == .approved { return true }
        if #available(iOS 26.4, *),
            authorizationStatus.rawValue == Self.approvedWithDataAccessRawValue
        {
            return true
        }
        return false
    }

    /// Raw value for `FamilyControls.AuthorizationStatus.approvedWithDataAccess`,
    /// added in iOS 26.4 after `.approved` (rawValue 2). Referencing by raw
    /// value keeps this file source-compatible with the Xcode 26.2
    /// FamilyControls SDK, which only declares `.notDetermined`, `.denied`,
    /// and `.approved`. Verified from the iOS 26.4
    /// `FamilyControls.framework` swiftinterface: the enum is `Int`-backed
    /// with auto-assigned raw values in declaration order.
    private static let approvedWithDataAccessRawValue = 3

    var hasSelectedApps: Bool {
        !activitySelection.applicationTokens.isEmpty
            || !activitySelection.categoryTokens.isEmpty
            || !activitySelection.webDomainTokens.isEmpty
            || !shieldedCategoryTokens.isEmpty
    }

    private let store: ManagedSettingsStore
    private let persistenceDefaults: UserDefaults

    private static let selectionDefaultsKey = "com.pomoduo.screentime.selection"
    private static let shieldedCategoryTokensDefaultsKey =
        "com.pomoduo.screentime.shieldedCategoryTokens"
    private static let categoryExceptionsDefaultsKey =
        "com.pomoduo.screentime.categoryExceptions"
    private static let webDomainCategoryExceptionsDefaultsKey =
        "com.pomoduo.screentime.webDomainCategoryExceptions"

    init(
        store: ManagedSettingsStore,
        persistenceDefaults: UserDefaults = .standard
    ) {
        self.store = store
        self.persistenceDefaults = persistenceDefaults
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
        restoreSelection()
    }

    func refreshAuthorizationStatus() {
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
    }

    func requestAuthorization() async {
        isRequestingAuthorization = true
        authorizationError = nil

        do {
            try await AuthorizationCenter.shared.requestAuthorization(
                for: .individual
            )
        } catch {
            if Self.shouldPresentAuthorizationAlert(for: error) {
                authorizationError = Self.userFacingMessage(for: error)
            }
        }

        refreshAuthorizationStatus()
        isRequestingAuthorization = false
    }

    func clearAuthorizationError() {
        authorizationError = nil
    }

    func clearSelection() {
        activitySelection = FamilyActivitySelection(includeEntireCategory: true)
        shieldedCategoryTokens = []
        categoryExceptions = []
        webDomainCategoryExceptions = []
        persistenceDefaults.removeObject(forKey: Self.selectionDefaultsKey)
        persistenceDefaults.removeObject(
            forKey: Self.shieldedCategoryTokensDefaultsKey
        )
        persistenceDefaults.removeObject(
            forKey: Self.categoryExceptionsDefaultsKey
        )
        persistenceDefaults.removeObject(
            forKey: Self.webDomainCategoryExceptionsDefaultsKey
        )
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        store.shield.webDomainCategories = nil

        ShieldSessionContext.writeSelection(
            FamilyActivitySelection(includeEntireCategory: true)
        )
        ShieldSessionContext.writeShieldedCategoryTokens([])
        ShieldSessionContext.writeCategoryExceptions([])
        ShieldSessionContext.writeWebDomainCategoryExceptions([])
    }

    /// Atomically replaces the live selection with a picker draft.
    ///
    /// `FamilyActivitySelection` has no field for "block this category except
    /// these apps." When the user deselects an app from a selected category,
    /// the picker can drop the category token and leave only the remaining
    /// enumerated app tokens. If we applied that literally, apps in the same
    /// category that the picker didn't enumerate would also become unblocked.
    ///
    /// Diffing against the previous committed selection lets us preserve the
    /// category shield and move the removed app/domain tokens into Apple's
    /// `ActivityCategoryPolicy.specific(_:except:)` exception list.
    func commitDraft(_ draft: FamilyActivitySelection) {
        let canonicalDraft = Self.canonicalizeRestoredSelection(draft)
        let previousSelection = activitySelection
        let previousShieldedCategories = shieldedCategoryTokens.isEmpty
            ? previousSelection.categoryTokens
            : shieldedCategoryTokens

        let lostCategories = previousShieldedCategories.subtracting(
            canonicalDraft.categoryTokens
        )
        let removedApps = previousSelection.applicationTokens.subtracting(
            canonicalDraft.applicationTokens
        )
        let removedWebDomains = previousSelection.webDomainTokens.subtracting(
            canonicalDraft.webDomainTokens
        )

        let draftHasSelections =
            !canonicalDraft.applicationTokens.isEmpty
            || !canonicalDraft.categoryTokens.isEmpty
            || !canonicalDraft.webDomainTokens.isEmpty
        let shouldRestoreCategories =
            draftHasSelections
            && !lostCategories.isEmpty
            && (!removedApps.isEmpty || !removedWebDomains.isEmpty
                || !categoryExceptions.isEmpty
                || !webDomainCategoryExceptions.isEmpty)
        let appResolution = CategoryExceptionResolver.resolve(
            previousCategories: previousShieldedCategories,
            previousItems: previousSelection.applicationTokens,
            previousExceptions: categoryExceptions,
            draftCategories: canonicalDraft.categoryTokens,
            draftItems: canonicalDraft.applicationTokens,
            restoresLostCategories: shouldRestoreCategories
        )
        let webResolution = CategoryExceptionResolver.resolve(
            previousCategories: previousShieldedCategories,
            previousItems: previousSelection.webDomainTokens,
            previousExceptions: webDomainCategoryExceptions,
            draftCategories: canonicalDraft.categoryTokens,
            draftItems: canonicalDraft.webDomainTokens,
            restoresLostCategories: shouldRestoreCategories
        )
        let restoredCategories = appResolution.categories
            .union(webResolution.categories)
        let derivedAppExceptions = appResolution.exceptions
        let derivedWebExceptions = webResolution.exceptions

        let finalCategories: Set<ActivityCategoryToken>
        let finalAppExceptions: Set<ApplicationToken>
        let finalWebExceptions: Set<WebDomainToken>
        if derivedAppExceptions.count + derivedWebExceptions.count
            > Self.categoryExceptionsLimit
        {
            finalCategories = restoredCategories
            finalAppExceptions = []
            finalWebExceptions = []
        } else {
            finalCategories = restoredCategories
            finalAppExceptions = derivedAppExceptions
            finalWebExceptions = derivedWebExceptions
        }

        var committed = FamilyActivitySelection(includeEntireCategory: true)
        committed.applicationTokens = canonicalDraft.applicationTokens
        committed.categoryTokens = canonicalDraft.categoryTokens
        committed.webDomainTokens = canonicalDraft.webDomainTokens

        shieldedCategoryTokens = finalCategories
        categoryExceptions = finalAppExceptions
        webDomainCategoryExceptions = finalWebExceptions
        activitySelection = committed
    }

    private func persistSelection() {
        guard let data = try? JSONEncoder().encode(activitySelection) else {
            return
        }

        persistenceDefaults.set(data, forKey: Self.selectionDefaultsKey)
        ShieldSessionContext.writeSelection(activitySelection)
    }

    private func persistShieldedCategoryTokens() {
        if shieldedCategoryTokens.isEmpty {
            persistenceDefaults.removeObject(
                forKey: Self.shieldedCategoryTokensDefaultsKey
            )
        } else if let data = try? JSONEncoder().encode(shieldedCategoryTokens) {
            persistenceDefaults.set(
                data,
                forKey: Self.shieldedCategoryTokensDefaultsKey
            )
        }
        ShieldSessionContext.writeShieldedCategoryTokens(
            shieldedCategoryTokens
        )
    }

    private func persistCategoryExceptions() {
        if let data = try? JSONEncoder().encode(categoryExceptions) {
            persistenceDefaults.set(
                data,
                forKey: Self.categoryExceptionsDefaultsKey
            )
        }
        ShieldSessionContext.writeCategoryExceptions(categoryExceptions)
    }

    private func persistWebDomainCategoryExceptions() {
        if let data = try? JSONEncoder().encode(webDomainCategoryExceptions) {
            persistenceDefaults.set(
                data,
                forKey: Self.webDomainCategoryExceptionsDefaultsKey
            )
        }
        ShieldSessionContext.writeWebDomainCategoryExceptions(
            webDomainCategoryExceptions
        )
    }

    private func restoreSelection() {
        if let shared = ShieldSessionContext.readSelection(),
            !shared.applicationTokens.isEmpty || !shared.categoryTokens.isEmpty
                || !shared.webDomainTokens.isEmpty
        {
            activitySelection = Self.canonicalizeRestoredSelection(shared)
            categoryExceptions = restoreCategoryExceptions()
            webDomainCategoryExceptions = restoreWebDomainCategoryExceptions()
            shieldedCategoryTokens =
                restoreShieldedCategoryTokens() ?? activitySelection.categoryTokens
            return
        }

        guard
            let data = persistenceDefaults.data(
                forKey: Self.selectionDefaultsKey
            ),
            let selection = try? JSONDecoder().decode(
                FamilyActivitySelection.self,
                from: data
            )
        else {
            return
        }

        activitySelection = Self.canonicalizeRestoredSelection(selection)
        ShieldSessionContext.writeSelection(activitySelection)
        categoryExceptions = restoreCategoryExceptions()
        webDomainCategoryExceptions = restoreWebDomainCategoryExceptions()
        shieldedCategoryTokens =
            restoreShieldedCategoryTokens() ?? activitySelection.categoryTokens
        ShieldSessionContext.writeShieldedCategoryTokens(shieldedCategoryTokens)
        ShieldSessionContext.writeCategoryExceptions(categoryExceptions)
        ShieldSessionContext.writeWebDomainCategoryExceptions(
            webDomainCategoryExceptions
        )
    }

    private func restoreShieldedCategoryTokens()
        -> Set<ActivityCategoryToken>?
    {
        if let shared = ShieldSessionContext.readShieldedCategoryTokens() {
            return shared
        }
        guard
            let data = persistenceDefaults.data(
                forKey: Self.shieldedCategoryTokensDefaultsKey
            ),
            let restored = try? JSONDecoder().decode(
                Set<ActivityCategoryToken>.self,
                from: data
            )
        else {
            return nil
        }
        return restored
    }

    private func restoreCategoryExceptions() -> Set<ApplicationToken> {
        if let shared = ShieldSessionContext.readCategoryExceptions() {
            return shared
        }
        guard
            let data = persistenceDefaults.data(
                forKey: Self.categoryExceptionsDefaultsKey
            ),
            let restored = try? JSONDecoder().decode(
                Set<ApplicationToken>.self,
                from: data
            )
        else {
            return []
        }
        return restored
    }

    private func restoreWebDomainCategoryExceptions()
        -> Set<WebDomainToken>
    {
        if let shared =
            ShieldSessionContext.readWebDomainCategoryExceptions()
        {
            return shared
        }
        guard
            let data = persistenceDefaults.data(
                forKey: Self.webDomainCategoryExceptionsDefaultsKey
            ),
            let restored = try? JSONDecoder().decode(
                Set<WebDomainToken>.self,
                from: data
            )
        else {
            return []
        }
        return restored
    }

    /// Rebuilds decoded selections so restored legacy values use the current
    /// include-entire-category picker behavior.
    static func canonicalizeRestoredSelection(
        _ decoded: FamilyActivitySelection
    ) -> FamilyActivitySelection {
        guard !decoded.includeEntireCategory else {
            return decoded
        }

        var canonical = FamilyActivitySelection(includeEntireCategory: true)
        canonical.applicationTokens = decoded.applicationTokens
        canonical.categoryTokens = decoded.categoryTokens
        canonical.webDomainTokens = decoded.webDomainTokens
        return canonical
    }

    private static func userFacingMessage(for error: Error) -> String {
        let nsError = error as NSError
        let loweredDescription = error.localizedDescription.localizedLowercase

        if loweredDescription.localizedStandardContains("denied") {
            return "Screen Time authorization was denied."
        }

        if loweredDescription.localizedStandardContains("restricted") {
            return "Screen Time is restricted on this device."
        }

        if loweredDescription.localizedStandardContains("unavailable") {
            return "Screen Time is unavailable on this device."
        }

        if nsError.domain.localizedStandardContains("familycontrols") {
            return
                "Could not enable app blocking on this device right now. Please try again."
        }

        return "Could not enable app blocking: \(error.localizedDescription)"
    }

    private static func shouldPresentAuthorizationAlert(for error: Error) -> Bool {
        let loweredDescription = error.localizedDescription.localizedLowercase
        return loweredDescription.localizedStandardContains("denied") == false
    }
}
