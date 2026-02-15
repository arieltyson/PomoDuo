//
//  AccessibilityAnnouncer.swift
//  PomoDuo
//
//  Created by Codex on 2/15/26.
//

import SwiftUI

/// Posts VoiceOver announcements for important timer state changes.
@MainActor
enum AccessibilityAnnouncer {
    static func announceStart(round: Int, totalRounds: Int) {
        post("Focus session started. Round \(round) of \(totalRounds).")
    }

    static func announcePause() {
        post("Timer paused.")
    }

    static func announceResume() {
        post("Timer resumed.")
    }

    static func announceRoundComplete() {
        post("Focus round complete. Nice work!")
    }

    static func announceBreakStarted(isLong: Bool) {
        let breakType = isLong ? "Long break" : "Short break"
        post("\(breakType) started. Take a rest.")
    }

    static func announceFocusResumed(round: Int, totalRounds: Int) {
        post("Focus started. Round \(round) of \(totalRounds).")
    }

    static func announceStop() {
        post("Session stopped.")
    }

    private static func post(_ message: String) {
        AccessibilityNotification.Announcement(message).post()
    }
}
