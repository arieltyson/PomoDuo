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
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .timer:
            "Focus"
        case .partner:
            "Partner"
        case .settings:
            "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .timer:
            "timer"
        case .partner:
            "heart.fill"
        case .settings:
            "gearshape"
        }
    }
}
