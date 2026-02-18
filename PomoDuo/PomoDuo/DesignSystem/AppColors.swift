import SwiftUI

/// PomoDuo's brand and semantic color system.
enum AppColors {
    // MARK: - Brand

    /// Deep lavender for primary actions and selected states.
    static let lavender = Color(red: 0.56, green: 0.44, blue: 0.86)

    /// Soft lilac for hero banner surfaces.
    static let lilac = Color(red: 0.73, green: 0.60, blue: 0.93)

    /// Pale violet for gradients and subtle accents.
    static let paleViolet = Color(red: 0.85, green: 0.76, blue: 0.97)

    // MARK: - Semantics

    static let focus = lavender
    static let breakTint = Color(red: 0.55, green: 0.78, blue: 0.78)
    static let success = Color(red: 0.45, green: 0.73, blue: 0.54)
    static let pauseTint = Color(red: 0.90, green: 0.70, blue: 0.40)
    static let stopTint = Color(red: 0.82, green: 0.34, blue: 0.38)

    // MARK: - Surfaces

    /// Requested main surface style.
    static let surface = Color.white

    static let surfaceSecondary = Color(red: 0.97, green: 0.96, blue: 0.99)
    static let secondaryLabel = Color(red: 0.42, green: 0.40, blue: 0.50)
}
