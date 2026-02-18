import SwiftUI

/// Posts VoiceOver announcements for important timer state changes.
@MainActor
enum AccessibilityAnnouncer {

    // MARK: - Solo Timer

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

    // MARK: - Paired Timer

    static func announcePairedSessionStarted(partnerName: String) {
        post(
            "Paired session started with \(partnerName). Waiting for partner to accept."
        )
    }

    static func announcePairedFocusBegan(
        round: Int,
        totalRounds: Int,
        partnerName: String
    ) {
        post(
            "Paired focus began with \(partnerName). Round \(round) of \(totalRounds)."
        )
    }

    static func announcePairedPause() {
        post("Paired session paused.")
    }

    static func announcePairedResume() {
        post("Paired session resumed.")
    }

    static func announcePairedBreak(isLong: Bool) {
        let breakType = isLong ? "Long break" : "Short break"
        post("\(breakType) started. Both partners can rest.")
    }

    static func announcePairedSessionCompleted() {
        post("Paired session complete. Great work together!")
    }

    static func announcePairedSessionEnded() {
        post("Paired session ended.")
    }

    // MARK: - Private

    private static func post(_ message: String) {
        AccessibilityNotification.Announcement(message).post()
    }
}
