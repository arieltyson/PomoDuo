import SwiftUI

/// Reusable gradient styles for the app shell and timer presentation.
///
/// ``banner(for:)`` and ``bannerFade(for:)`` accept a ``ColorScheme``
/// so they can provide rich, saturated dark-mode variants while keeping
/// soft pastels in light mode. The ring gradients use mid-range brand
/// accents that read well on any background and remain static.
enum AppGradients {

    // MARK: - Scheme-Aware Gradients

    /// Horizontal banner gradient for the session header.
    ///
    /// Light mode uses the familiar soft pastel (lilac → paleViolet).
    /// Dark mode deepens and saturates the violet to maintain strong
    /// contrast for the white text that sits on top.
    static func banner(for scheme: ColorScheme) -> LinearGradient {
        switch scheme {
        case .dark:
            LinearGradient(
                colors: [
                    Color(red: 0.38, green: 0.26, blue: 0.62),
                    Color(red: 0.48, green: 0.34, blue: 0.72),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        default:
            LinearGradient(
                colors: [AppColors.lilac, AppColors.paleViolet],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }

    /// Soft vertical fade from the banner into the content surface.
    ///
    /// Bridges the colored header into the main canvas background.
    /// Light mode fades from pale violet; dark mode fades from the
    /// deeper banner endpoint to avoid a ghostly pale strip.
    static func bannerFade(for scheme: ColorScheme) -> LinearGradient {
        switch scheme {
        case .dark:
            LinearGradient(
                colors: [
                    Color(red: 0.48, green: 0.34, blue: 0.72).opacity(0.22),
                    .clear,
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        default:
            LinearGradient(
                colors: [AppColors.paleViolet.opacity(0.28), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    // MARK: - Static Ring Gradients

    /// Focus-phase angular ring gradient.
    static let focusRing = AngularGradient(
        colors: [AppColors.lavender, AppColors.lilac, AppColors.lavender],
        center: .center
    )

    /// Break-phase angular ring gradient.
    static let breakRing = AngularGradient(
        colors: [
            AppColors.breakTint,
            AppColors.breakTint.opacity(0.65),
            AppColors.breakTint,
        ],
        center: .center
    )
}
