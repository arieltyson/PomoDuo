//
//  PairingState.swift
//  PomoDuo
//
//  Created by Codex on 2/15/26.
//

import Foundation

/// Current state of the partner pairing flow.
enum PairingState: Sendable, Equatable {
    /// No partner is connected.
    case unpaired

    /// Local user generated a code and is waiting for someone to join.
    case waitingForPartner(code: PairCode)

    /// Local user is attempting to join with an entered code.
    case joining

    /// Local user is connected to a partner.
    case paired(PartnerProfile)

    /// Pairing encountered an error.
    case error(String)
}
