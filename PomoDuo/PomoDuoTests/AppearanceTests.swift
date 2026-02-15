//
//  AppearanceTests.swift
//  PomoDuoTests
//
//  Created by Codex on 2/15/26.
//

import Foundation
import SwiftUI
import Testing
@testable import PomoDuo

@MainActor
struct AppearanceManagerTests {
    @Test func defaultsToSystemAppearance() {
        guard let defaults = makeIsolatedDefaults(named: #function) else {
            #expect(Bool(false), "Failed to create isolated defaults")
            return
        }

        let manager = AppearanceManager(userDefaults: defaults)
        #expect(manager.selectedAppearance == .system)
        #expect(manager.preferredColorScheme == nil)
    }

    @Test func loadsPersistedAppearance() {
        guard let defaults = makeIsolatedDefaults(named: #function) else {
            #expect(Bool(false), "Failed to create isolated defaults")
            return
        }

        defaults.set(AppAppearance.dark.rawValue, forKey: AppearanceManager.storageKey)

        let manager = AppearanceManager(userDefaults: defaults)
        #expect(manager.selectedAppearance == .dark)
        #expect(manager.preferredColorScheme == .dark)
    }

    @Test func persistsUpdatedAppearance() {
        guard let defaults = makeIsolatedDefaults(named: #function) else {
            #expect(Bool(false), "Failed to create isolated defaults")
            return
        }

        let manager = AppearanceManager(userDefaults: defaults)
        manager.selectedAppearance = .light

        let savedRawValue = defaults.string(forKey: AppearanceManager.storageKey)
        #expect(savedRawValue == AppAppearance.light.rawValue)
    }

    @Test func appAppearanceMetadataIsStable() {
        #expect(AppAppearance.system.title == "System")
        #expect(AppAppearance.light.title == "Light")
        #expect(AppAppearance.dark.title == "Dark")
        #expect(!AppAppearance.system.detailText.isEmpty)
        #expect(!AppAppearance.light.detailText.isEmpty)
        #expect(!AppAppearance.dark.detailText.isEmpty)
    }

    private func makeIsolatedDefaults(named testName: String) -> UserDefaults? {
        let suiteName = "com.pomoduo.tests.appearance.\(testName)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return nil
        }

        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
