import Foundation
import Observation

/// Derived state for session history, charting, and streak calculations.
@MainActor
@Observable
final class SessionHistoryViewModel {

    // MARK: - Filter

    /// Active type filter for history list and chart rendering.
    var activeFilter = SessionTypeFilter.all

    // MARK: - Aggregate Stats

    private(set) var weeklySummaries: [DailyFocusSummary] = []
    private(set) var allTimeFocusMinutes = 0
    private(set) var allTimeSessionCount = 0
    private(set) var currentStreak = 0

    private(set) var soloFocusMinutes = 0
    private(set) var soloSessionCount = 0

    private(set) var pairedFocusMinutes = 0
    private(set) var pairedSessionCount = 0

    // MARK: - Refresh

    func refresh(from sessions: [CompletedSession], userID: String? = nil) {
        let scoped = scopedSessions(from: sessions, userID: userID)
        computeAllTime(from: scoped)
        computeWeekly(from: scoped)
        computeStreak(from: scoped)
    }

    /// Returns sessions visible for the provided identity.
    ///
    /// When `userID` is non-`nil`, includes sessions for that user and legacy
    /// sessions with `nil` user attribution.
    func scopedSessions(from sessions: [CompletedSession], userID: String?)
        -> [CompletedSession]
    {
        guard let userID else { return sessions }
        return sessions.filter { $0.userID == nil || $0.userID == userID }
    }

    /// Applies the current session type filter to a list.
    func filteredSessions(from sessions: [CompletedSession])
        -> [CompletedSession]
    {
        switch activeFilter {
        case .all:
            sessions
        case .solo:
            sessions.filter { $0.sessionType == .solo }
        case .paired:
            sessions.filter { $0.sessionType == .paired }
        }
    }

    // MARK: - Private

    private func computeAllTime(from sessions: [CompletedSession]) {
        allTimeSessionCount = sessions.count

        var totalMinutes = 0
        var soloMinutes = 0
        var soloCount = 0
        var pairedMinutes = 0
        var pairedCount = 0

        for session in sessions {
            totalMinutes += session.focusMinutes

            switch session.sessionType {
            case .solo:
                soloCount += 1
                soloMinutes += session.focusMinutes
            case .paired:
                pairedCount += 1
                pairedMinutes += session.focusMinutes
            }
        }

        allTimeFocusMinutes = totalMinutes
        soloFocusMinutes = soloMinutes
        soloSessionCount = soloCount
        pairedFocusMinutes = pairedMinutes
        pairedSessionCount = pairedCount
    }

    private func computeWeekly(from sessions: [CompletedSession]) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        var buckets:
            [Date: (
                minutes: Int, sessions: Int, soloMinutes: Int,
                pairedMinutes: Int
            )] = [:]
        var segmentsByDay: [Date: [FocusSegment]] = [:]

        for dayOffset in 0..<7 {
            guard
                let day = calendar.date(
                    byAdding: .day,
                    value: -dayOffset,
                    to: today
                )
            else {
                continue
            }
            buckets[day] = (
                minutes: 0, sessions: 0, soloMinutes: 0, pairedMinutes: 0
            )
            segmentsByDay[day] = []
        }

        for session in sessions {
            guard var bucket = buckets[session.dayBucket] else { continue }

            bucket.minutes += session.focusMinutes
            bucket.sessions += 1

            let isPaired: Bool
            switch session.sessionType {
            case .solo:
                bucket.soloMinutes += session.focusMinutes
                isPaired = false
            case .paired:
                bucket.pairedMinutes += session.focusMinutes
                isPaired = true
            }

            buckets[session.dayBucket] = bucket
            segmentsByDay[session.dayBucket, default: []].append(
                FocusSegment(minutes: session.focusMinutes, isPaired: isPaired)
            )
        }

        weeklySummaries =
            buckets
            .map { day, values in
                DailyFocusSummary(
                    day: day,
                    totalMinutes: values.minutes,
                    sessionCount: values.sessions,
                    soloMinutes: values.soloMinutes,
                    pairedMinutes: values.pairedMinutes,
                    segments: segmentsByDay[day] ?? []
                )
            }
            .sorted { $0.day < $1.day }
    }

    private func computeStreak(from sessions: [CompletedSession]) {
        let calendar = Calendar.current
        var day = calendar.startOfDay(for: .now)
        let activeDays = Set(sessions.map(\.dayBucket))

        var streak = 0
        while activeDays.contains(day) {
            streak += 1
            guard
                let previousDay = calendar.date(
                    byAdding: .day,
                    value: -1,
                    to: day
                )
            else { break }
            day = previousDay
        }

        currentStreak = streak
    }
}
