//
//  OnboardingStep.swift
//  PomoDuo
//
//  Created by Codex on 2/15/26.
//

import Foundation

/// Ordered steps shown during first-launch onboarding.
enum OnboardingStep: Int, CaseIterable, Identifiable {
    case welcome
    case focus
    case partner
    case notifications
    case appBlocking

    var id: Int {
        rawValue
    }

    var title: String {
        switch self {
        case .welcome:
            "Welcome to PomoDuo"
        case .focus:
            "Own Your Focus"
        case .partner:
            "Study Together"
        case .notifications:
            "Stay in Sync"
        case .appBlocking:
            "Protect Deep Work"
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
            "Use Screen Time shields during focus rounds to remove distracting apps automatically."
        }
    }

    var symbolName: String {
        switch self {
        case .welcome:
            "sparkles"
        case .focus:
            "timer"
        case .partner:
            "person.2.fill"
        case .notifications:
            "bell.badge.fill"
        case .appBlocking:
            "shield.lefthalf.filled.badge.checkmark"
        }
    }

    var accentSymbolName: String {
        switch self {
        case .welcome:
            "circle.grid.2x2.fill"
        case .focus:
            "brain.head.profile"
        case .partner:
            "heart.fill"
        case .notifications:
            "calendar.badge.clock"
        case .appBlocking:
            "hourglass.badge.plus"
        }
    }

    var ctaTitle: String {
        switch self {
        case .notifications:
            "Allow Notifications"
        case .appBlocking:
            "Open App Blocking"
        default:
            "Continue"
        }
    }
}
