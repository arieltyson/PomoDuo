import UIKit

/// Home Screen quick actions available from the app icon.
enum QuickAction: String, CaseIterable, Sendable {
    case reportBug = "com.arieljtyson.PomoDuo.quickAction.reportBug"
    case suggestFeature = "com.arieljtyson.PomoDuo.quickAction.suggestFeature"

    init?(shortcutItem: UIApplicationShortcutItem) {
        self.init(rawValue: shortcutItem.type)
    }

    var shortcutItem: UIApplicationShortcutItem {
        switch self {
        case .reportBug:
            UIApplicationShortcutItem(
                type: rawValue,
                localizedTitle: "Report a Bug",
                localizedSubtitle: "Tell us what went wrong",
                icon: UIApplicationShortcutIcon(systemImageName: "ladybug"),
                userInfo: nil
            )
        case .suggestFeature:
            UIApplicationShortcutItem(
                type: rawValue,
                localizedTitle: "Suggest a Feature",
                localizedSubtitle: "Share what you'd love to see",
                icon: UIApplicationShortcutIcon(systemImageName: "lightbulb"),
                userInfo: nil
            )
        }
    }

    /// Registers all quick actions on the shared application.
    static func registerAll(in application: UIApplication = .shared) {
        application.shortcutItems = allCases.map(\.shortcutItem)
    }
}
