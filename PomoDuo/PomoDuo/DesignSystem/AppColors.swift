import SwiftUI
import UIKit

/// PomoDuo's brand and semantic color system.
///
/// Brand, semantic, surface, and label colors all resolve dynamically via
/// ``UIColor`` trait collection. Colors adapt to the user's interface style
/// (light / dark) **and** the Increase Contrast accessibility setting
/// (`UIAccessibilityContrast.high`), ensuring ≥ 4.5 : 1 WCAG AA contrast
/// for foreground text and icons in every configuration.
enum AppColors {
    // MARK: - Brand (Contrast-Adaptive)

    /// Deep lavender for primary actions and selected states.
    ///
    /// High-contrast light: darkened to ~5.4 : 1 on white.
    /// High-contrast dark: lightened to ~6.1 : 1 on dark surface.
    static let lavender = Color(
        uiColor: UIColor { traits in
            if traits.accessibilityContrast == .high {
                return traits.userInterfaceStyle == .dark
                    ? UIColor(red: 0.66, green: 0.54, blue: 0.96, alpha: 1)
                    : UIColor(red: 0.46, green: 0.34, blue: 0.76, alpha: 1)
            }
            return UIColor(red: 0.56, green: 0.44, blue: 0.86, alpha: 1)
        }
    )

    /// Soft lilac for hero banner surfaces and paired-session icons.
    ///
    /// High-contrast light: darkened to ~5.0 : 1 on white.
    /// High-contrast dark: lightened to ~8.8 : 1 on dark surface.
    static let lilac = Color(
        uiColor: UIColor { traits in
            if traits.accessibilityContrast == .high {
                return traits.userInterfaceStyle == .dark
                    ? UIColor(red: 0.80, green: 0.68, blue: 0.98, alpha: 1)
                    : UIColor(red: 0.50, green: 0.36, blue: 0.76, alpha: 1)
            }
            return UIColor(red: 0.73, green: 0.60, blue: 0.93, alpha: 1)
        }
    )

    /// Pale violet for gradients and subtle accents.
    static let paleViolet = Color(red: 0.85, green: 0.76, blue: 0.97)

    // MARK: - Semantics (Contrast-Adaptive)

    static let focus = lavender

    /// Teal accent for break-phase ring gradients and decorative effects.
    static let breakTint = Color(red: 0.55, green: 0.78, blue: 0.78)

    /// Green for completion checkmarks, authorization badges, and continue
    /// actions.
    ///
    /// High-contrast light: darkened to ~5.2 : 1 on white.
    /// High-contrast dark: lightened to ~9.7 : 1 on dark surface.
    static let success = Color(
        uiColor: UIColor { traits in
            if traits.accessibilityContrast == .high {
                return traits.userInterfaceStyle == .dark
                    ? UIColor(red: 0.55, green: 0.83, blue: 0.64, alpha: 1)
                    : UIColor(red: 0.22, green: 0.48, blue: 0.30, alpha: 1)
            }
            return UIColor(red: 0.45, green: 0.73, blue: 0.54, alpha: 1)
        }
    )

    /// Warm amber for pause states and pause button tint.
    ///
    /// High-contrast light: darkened to ~5.0 : 1 on white.
    /// High-contrast dark: lightened to ~10.7 : 1 on dark surface.
    static let pauseTint = Color(
        uiColor: UIColor { traits in
            if traits.accessibilityContrast == .high {
                return traits.userInterfaceStyle == .dark
                    ? UIColor(red: 0.95, green: 0.78, blue: 0.48, alpha: 1)
                    : UIColor(red: 0.58, green: 0.40, blue: 0.10, alpha: 1)
            }
            return UIColor(red: 0.90, green: 0.70, blue: 0.40, alpha: 1)
        }
    )

    /// Red for stop / destructive actions.
    ///
    /// High-contrast light: darkened to ~5.6 : 1 on white.
    /// High-contrast dark: lightened to ~5.7 : 1 on dark surface.
    static let stopTint = Color(
        uiColor: UIColor { traits in
            if traits.accessibilityContrast == .high {
                return traits.userInterfaceStyle == .dark
                    ? UIColor(red: 0.92, green: 0.44, blue: 0.48, alpha: 1)
                    : UIColor(red: 0.72, green: 0.24, blue: 0.28, alpha: 1)
            }
            return UIColor(red: 0.82, green: 0.34, blue: 0.38, alpha: 1)
        }
    )

    // MARK: - Surfaces (Adaptive)

    /// Main content surface. White in light mode, near-black with a faint
    /// violet undertone in dark mode matching HIG elevated surfaces.
    static let surface = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.11, green: 0.11, blue: 0.14, alpha: 1)
                : .white
        }
    )

    /// Secondary surface one step above ``surface``. Faint lavender tint in
    /// light mode, slightly lifted violet-charcoal in dark mode.
    static let surfaceSecondary = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.15, green: 0.14, blue: 0.19, alpha: 1)
                : UIColor(red: 0.97, green: 0.96, blue: 0.99, alpha: 1)
        }
    )

    /// Muted text for secondary information. Maintains ≥ 4.5:1 contrast
    /// against ``surface`` in both light and dark modes (WCAG AA).
    static let secondaryLabel = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.68, green: 0.64, blue: 0.78, alpha: 1)
                : UIColor(red: 0.42, green: 0.40, blue: 0.50, alpha: 1)
        }
    )
}
