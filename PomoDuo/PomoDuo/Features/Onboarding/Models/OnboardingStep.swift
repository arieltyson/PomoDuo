import SwiftUI

/// Ordered steps shown during first-launch onboarding.
///
/// Each case carries all the visual and textual metadata needed to render
/// a fully immersive onboarding page — hero symbols, gradient palette,
/// and call-to-action copy.
enum OnboardingStep: Int, CaseIterable, Identifiable, Sendable {
    case welcome
    case focus
    case partner
    case notifications
    case appBlocking

    var id: Int { rawValue }

    // MARK: - Copy

    var title: String {
        switch self {
        case .welcome: "Welcome to PomoDuo"
        case .focus: "Own Your Focus"
        case .partner: "Study Together"
        case .notifications: "Stay in Sync"
        case .appBlocking: "Protect Deep Work"
        }
    }

    var message: String {
        switch self {
        case .welcome:
            "Build focused momentum solo or with a partner, one round at a time."
        case .focus:
            "Start a focus round with one tap and track progress with Live Activities."
        case .partner:
            "Pair with a friend to keep each other accountable through every session."
        case .notifications:
            "Enable notifications so PomoDuo can alert you right when rounds and breaks end."
        case .appBlocking:
            "Optionally use Screen Time shields during focus rounds to remove distracting apps automatically."
        }
    }

    var ctaTitle: String {
        switch self {
        case .notifications: "Allow Notifications"
        case .appBlocking: "Continue to Timer"
        default: "Continue"
        }
    }

    // MARK: - Symbols

    /// Primary hero SF Symbol displayed large and centered.
    var heroSymbol: String {
        switch self {
        case .welcome: "sparkles"
        case .focus: "timer"
        case .partner: "person.2.fill"
        case .notifications: "bell.badge.fill"
        case .appBlocking: "shield.lefthalf.filled.badge.checkmark"
        }
    }

    /// Secondary companion symbol for the icon pair.
    var accentSymbol: String {
        switch self {
        case .welcome: "circle.grid.2x2.fill"
        case .focus: "brain.head.profile"
        case .partner: "heart.fill"
        case .notifications: "calendar.badge.clock"
        case .appBlocking: "hourglass.badge.plus"
        }
    }

    // MARK: - Theme

    /// Two-stop gradient colors unique to each step, creating visual
    /// progression as the user moves through onboarding.
    var gradientColors: [Color] {
        switch self {
        case .welcome:
            [AppColors.lilac.opacity(0.35), AppColors.paleViolet.opacity(0.18)]
        case .focus:
            [AppColors.lavender.opacity(0.38), AppColors.lilac.opacity(0.2)]
        case .partner:
            [Color(red: 0.62, green: 0.44, blue: 0.88).opacity(0.35),
             AppColors.lilac.opacity(0.22)]
        case .notifications:
            [AppColors.lavender.opacity(0.32), AppColors.paleViolet.opacity(0.2)]
        case .appBlocking:
            [Color(red: 0.48, green: 0.36, blue: 0.78).opacity(0.38),
             AppColors.lavender.opacity(0.18)]
        }
    }

    /// Accent color used for the hero symbol background.
    var heroTint: Color {
        switch self {
        case .welcome: AppColors.lilac
        case .focus: AppColors.lavender
        case .partner: Color(red: 0.62, green: 0.44, blue: 0.88)
        case .notifications: AppColors.lavender
        case .appBlocking: Color(red: 0.48, green: 0.36, blue: 0.78)
        }
    }
}
