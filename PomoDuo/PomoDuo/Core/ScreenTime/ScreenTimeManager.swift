//
//  ScreenTimeManager.swift
//  PomoDuo
//
//  Created by Codex on 2/15/26.
//

import FamilyControls
import ManagedSettings
import Observation
import Foundation

/// Coordinates Screen Time authorization and selected apps/categories to block.
@MainActor
@Observable
final class ScreenTimeManager {
    private(set) var authorizationStatus: AuthorizationStatus

    var activitySelection = FamilyActivitySelection() {
        didSet {
            persistSelection()
        }
    }

    var isAuthorized: Bool {
        authorizationStatus == .approved
    }

    var hasSelectedApps: Bool {
        !activitySelection.applicationTokens.isEmpty
            || !activitySelection.categoryTokens.isEmpty
    }

    private let store: ManagedSettingsStore

    private static let selectionDefaultsKey = "com.pomoduo.screentime.selection"

    init(store: ManagedSettingsStore = ManagedSettingsStore()) {
        self.store = store
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
        restoreSelection()
    }

    func refreshAuthorizationStatus() {
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
    }

    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        } catch {
            // Keep the latest status below; user may have denied authorization.
        }

        refreshAuthorizationStatus()
    }

    func clearSelection() {
        activitySelection = FamilyActivitySelection()
        UserDefaults.standard.removeObject(forKey: Self.selectionDefaultsKey)
        store.shield.applications = nil
        store.shield.applicationCategories = nil
    }

    private func persistSelection() {
        guard let data = try? JSONEncoder().encode(activitySelection) else { return }
        UserDefaults.standard.set(data, forKey: Self.selectionDefaultsKey)
    }

    private func restoreSelection() {
        guard
            let data = UserDefaults.standard.data(forKey: Self.selectionDefaultsKey),
            let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        else {
            return
        }

        activitySelection = selection
    }
}
