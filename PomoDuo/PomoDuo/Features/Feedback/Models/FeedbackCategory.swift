import SwiftUI

/// Supported feedback categories.
enum FeedbackCategory: String, Identifiable, Sendable {
    case bug
    case feature

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bug:
            "Report a Bug"
        case .feature:
            "Suggest a Feature"
        }
    }

    var systemImageName: String {
        switch self {
        case .bug:
            "ladybug"
        case .feature:
            "lightbulb"
        }
    }

    var tintColor: Color {
        switch self {
        case .bug:
            .red
        case .feature:
            .yellow
        }
    }

    var prompt: String {
        switch self {
        case .bug:
            "Describe what happened and what you expected instead."
        case .feature:
            "Describe the feature you want in PomoDuo."
        }
    }

    var placeholder: String {
        switch self {
        case .bug:
            "When I start a focus session, the timer freezes after a few seconds..."
        case .feature:
            "It would help if I could set custom blocked app lists per timer preset..."
        }
    }

    var emailSubject: String {
        switch self {
        case .bug:
            "PomoDuo Bug Report"
        case .feature:
            "PomoDuo Feature Suggestion"
        }
    }

    var accessibilityFieldLabel: String {
        switch self {
        case .bug:
            "Bug description"
        case .feature:
            "Feature suggestion description"
        }
    }
}
