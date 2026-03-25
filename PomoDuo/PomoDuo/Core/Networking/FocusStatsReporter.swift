import Foundation
import Observation
import OSLog

/// Lightweight reporter that syncs completed focus minutes to Firestore
/// for leaderboard display. Injected via the SwiftUI environment.
@MainActor
@Observable
final class FocusStatsReporter {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.arieljtyson.PomoDuo",
        category: "FocusStatsReporter"
    )

    private let friendService: any FriendService

    init(friendService: any FriendService) {
        self.friendService = friendService
    }

    /// Reports focus minutes in a fire-and-forget manner.
    /// Failures are logged but never surface to the user.
    func report(focusMinutes: Int) {
        guard focusMinutes > 0 else { return }

        Task {
            do {
                try await friendService.reportFocusSession(minutes: focusMinutes)
                Self.logger.info("Reported \(focusMinutes, privacy: .public) focus minutes to leaderboard.")
            } catch {
                Self.logger.error("Failed to report focus stats: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
