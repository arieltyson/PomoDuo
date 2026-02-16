//
//  AppTab.swift
//  PomoDuo
//
//  Created by Codex on 2/15/26.
//

import Foundation

/// Tabs available in PomoDuo's root navigation.
enum AppTab: String, CaseIterable, Identifiable, Sendable {
    case timer
    case partner
    case history
    case settings

    nonisolated var id: String { rawValue }

    nonisolated var title: String {
        switch self {
        case .timer:
            "Focus"
        case .partner:
            "Partner"
        case .history:
            "History"
        case .settings:
            "Settings"
        }
    }

    nonisolated var systemImage: String {
        switch self {
        case .timer:
            "timer"
        case .partner:
            "heart.fill"
        case .history:
            "clock.arrow.circlepath"
        case .settings:
            "gearshape"
        }
    }
}
