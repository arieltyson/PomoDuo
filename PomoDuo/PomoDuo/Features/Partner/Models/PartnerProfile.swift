//
//  PartnerProfile.swift
//  PomoDuo
//
//  Created by Codex on 2/15/26.
//

import Foundation

/// Lightweight profile for a connected study partner.
struct PartnerProfile: Sendable, Equatable, Codable, Identifiable {
    let id: String
    let displayName: String
    let pairedAt: Date
}
