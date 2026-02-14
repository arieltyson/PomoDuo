//
//  StudySession.swift
//  PomoDuo
//
//  Created by Ariel Tyson on 2/14/26.
//

import Foundation

/// The shared source of truth for a PomoDuo study session.
/// Both devices derive their local state from this single structure.
struct StudySession: Codable, Sendable, Identifiable, Equatable {
    let id: String
    let partnerA: String
    let partnerB: String
    var state: SessionState
    var startTime: Date
    /// The absolute time the current period (focus or break) ends.
    /// Both devices calculate their countdown from this value, which removes per-tick syncing.
    var targetEndDate: Date
    var isPaused: Bool
    var pausedBy: String?
    var currentRound: Int
    var totalRounds: Int

    /// Returns whether the given user ID is a member of this session.
    func isMember(_ userID: String) -> Bool {
        userID == partnerA || userID == partnerB
    }

    /// Returns the partner's user ID for a given session member.
    func partnerID(for userID: String) -> String? {
        switch userID {
        case partnerA:
            partnerB
        case partnerB:
            partnerA
        default:
            nil
        }
    }
}
