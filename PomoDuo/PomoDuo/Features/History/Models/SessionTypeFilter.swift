//
//  SessionTypeFilter.swift
//  PomoDuo
//
//  Created by Codex on 2/16/26.
//

import Foundation

/// Filter applied to session history data surfaces.
enum SessionTypeFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case solo
    case paired

    nonisolated var id: String { rawValue }

    nonisolated var title: String {
        switch self {
        case .all:
            "All"
        case .solo:
            "Solo"
        case .paired:
            "Paired"
        }
    }
}
