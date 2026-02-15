//
//  AppAppearance.swift
//  PomoDuo
//
//  Created by Codex on 2/15/26.
//

import SwiftUI

/// User-selectable app-wide appearance preference.
enum AppAppearance: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: Self { self }

    var title: String {
        switch self {
        case .system:
            "System"
        case .light:
            "Light"
        case .dark:
            "Dark"
        }
    }

    var detailText: String {
        switch self {
        case .system:
            "System follows your device settings."
        case .light:
            "Light keeps a bright interface throughout the app."
        case .dark:
            "Dark keeps a dimmed interface throughout the app."
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system:
            nil
        case .light:
            .light
        case .dark:
            .dark
        }
    }
}
