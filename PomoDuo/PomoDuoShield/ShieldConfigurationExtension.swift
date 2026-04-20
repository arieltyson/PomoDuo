import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Custom shield displayed when the user attempts to open a blocked app
/// during a PomoDuo focus session.
///
/// Instead of the generic iOS "Screen Time Limit" screen, this shows:
/// - The partner's name and an encouraging message
/// - Remaining focus time
/// - PomoDuo-branded lavender styling
///
/// Session context is read from the shared App Group via ``ShieldSessionContext``.
///
/// - Note: The class name must match `NSExtensionPrincipalClass` in
///   `PomoDuoShield/Info.plist`.
class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    // MARK: - Brand Colors (matches AppColors)

    private let lavender = UIColor(
        red: 0.56,
        green: 0.44,
        blue: 0.86,
        alpha: 1.0
    )

    // MARK: - Shield Overrides

    override func configuration(
        shielding application: Application
    ) -> ShieldConfiguration {
        return makeConfiguration()
    }

    override func configuration(
        shielding application: Application,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        return makeConfiguration()
    }

    override func configuration(
        shielding webDomain: WebDomain
    ) -> ShieldConfiguration {
        return makeConfiguration()
    }

    override func configuration(
        shielding webDomain: WebDomain,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        return makeConfiguration()
    }

    // MARK: - Configuration Builder

    private func makeConfiguration() -> ShieldConfiguration {
        let partnerName = ShieldSessionContext.partnerName ?? "Your partner"
        let phase = ShieldSessionContext.sessionPhase ?? "Focus"

        let title: ShieldConfiguration.Label
        let subtitle: ShieldConfiguration.Label

        switch phase {
        case "Focus":
            title = .init(text: "Stay Focused 💜", color: lavender)
            subtitle = .init(
                text: buildFocusSubtitle(partnerName: partnerName),
                color: .secondaryLabel
            )
        case "Short Break", "Long Break":
            title = .init(text: "Break Time ☕", color: lavender)
            subtitle = .init(
                text: "Enjoy your break — focus resumes soon!",
                color: .secondaryLabel
            )
        default:
            title = .init(text: "Stay Focused 💜", color: lavender)
            subtitle = .init(
                text: "\(partnerName) is counting on you!",
                color: .secondaryLabel
            )
        }

        return ShieldConfiguration(
            backgroundBlurStyle: .systemThinMaterial,
            backgroundColor: lavender.withAlphaComponent(0.06),
            icon: UIImage(systemName: "brain.head.profile"),
            title: title,
            subtitle: subtitle,
            primaryButtonLabel: .init(text: "Stay Focused", color: .white),
            primaryButtonBackgroundColor: lavender
        )
    }

    /// Builds an encouraging subtitle with remaining time if available.
    private func buildFocusSubtitle(partnerName: String) -> String {
        guard let endDate = ShieldSessionContext.targetEndDate else {
            return "\(partnerName) is counting on you!"
        }

        let remaining = endDate.timeIntervalSinceNow

        guard remaining > 0 else {
            return "Almost done — hang in there!"
        }

        let minutes = Int(remaining) / 60

        if minutes >= 2 {
            return "\(partnerName) is counting on you! \(minutes) min left."
        } else if minutes == 1 {
            return "Just 1 minute left — you've got this!"
        } else {
            return "Almost done — less than a minute left!"
        }
    }
}
