import Foundation
import SwiftUI
import Testing
import UIKit

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

        defaults.set(
            AppAppearance.dark.rawValue,
            forKey: AppearanceManager.storageKey
        )

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

        let savedRawValue = defaults.string(
            forKey: AppearanceManager.storageKey
        )
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

// MARK: - Adaptive Color Tests

@MainActor
struct AdaptiveColorTests {

    // MARK: - Surface Color Resolution

    @Test func surfaceResolvesToWhiteInLightMode() {
        let resolved = resolvedColor(AppColors.surface, style: .light)
        #expect(resolved.red > 0.99)
        #expect(resolved.green > 0.99)
        #expect(resolved.blue > 0.99)
    }

    @Test func surfaceResolvesToDarkInDarkMode() {
        let resolved = resolvedColor(AppColors.surface, style: .dark)
        #expect(resolved.red < 0.15)
        #expect(resolved.green < 0.15)
        #expect(resolved.blue < 0.18)
    }

    @Test func surfaceSecondaryIsLighterThanSurfaceInDarkMode() {
        let surface = resolvedColor(AppColors.surface, style: .dark)
        let secondary = resolvedColor(AppColors.surfaceSecondary, style: .dark)

        let surfaceLuminance = relativeLuminance(surface)
        let secondaryLuminance = relativeLuminance(secondary)
        #expect(secondaryLuminance > surfaceLuminance)
    }

    // MARK: - WCAG Contrast Compliance

    @Test func secondaryLabelMeetsWCAGAAInLightMode() {
        let label = resolvedColor(AppColors.secondaryLabel, style: .light)
        let surface = resolvedColor(AppColors.surface, style: .light)
        let ratio = contrastRatio(label, surface)
        #expect(ratio >= 4.5, "Light mode secondaryLabel contrast \(ratio) < 4.5:1")
    }

    @Test func secondaryLabelMeetsWCAGAAInDarkMode() {
        let label = resolvedColor(AppColors.secondaryLabel, style: .dark)
        let surface = resolvedColor(AppColors.surface, style: .dark)
        let ratio = contrastRatio(label, surface)
        #expect(ratio >= 4.5, "Dark mode secondaryLabel contrast \(ratio) < 4.5:1")
    }

    // MARK: - Helpers

    private struct RGBComponents {
        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat
    }

    private func resolvedColor(
        _ color: Color,
        style: UIUserInterfaceStyle
    ) -> RGBComponents {
        let traits = UITraitCollection(userInterfaceStyle: style)
        let resolved = UIColor(color).resolvedColor(with: traits)

        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        resolved.getRed(&r, green: &g, blue: &b, alpha: &a)

        return RGBComponents(red: r, green: g, blue: b)
    }

    private func relativeLuminance(_ c: RGBComponents) -> Double {
        func linearize(_ channel: CGFloat) -> Double {
            let v = Double(channel)
            return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }

        return 0.2126 * linearize(c.red)
            + 0.7152 * linearize(c.green)
            + 0.0722 * linearize(c.blue)
    }

    private func contrastRatio(
        _ foreground: RGBComponents,
        _ background: RGBComponents
    ) -> Double {
        let l1 = relativeLuminance(foreground)
        let l2 = relativeLuminance(background)
        let lighter = max(l1, l2)
        let darker = min(l1, l2)
        return (lighter + 0.05) / (darker + 0.05)
    }
}
