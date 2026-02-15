//
//  SessionHistoryViewModel.swift
//  PomoDuo
//
//  Created by Codex on 2/15/26.
//

import Foundation
import Observation

/// Derived state for session history, charting, and streak calculations.
@MainActor
@Observable
final class SessionHistoryViewModel {
    private(set) var weeklySummaries: [DailyFocusSummary] = []
    private(set) var allTimeFocusMinutes = 0
    private(set) var allTimeSessionCount = 0
    private(set) var currentStreak = 0

    func refresh(from sessions: [CompletedSession]) {
        computeAllTime(from: sessions)
        computeWeekly(from: sessions)
        computeStreak(from: sessions)
    }

    private func computeAllTime(from sessions: [CompletedSession]) {
        allTimeSessionCount = sessions.count
        allTimeFocusMinutes = sessions.reduce(0) { partial, session in
            partial + session.focusMinutes
        }
    }

    private func computeWeekly(from sessions: [CompletedSession]) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        var buckets: [Date: (minutes: Int, sessions: Int)] = [:]
        for dayOffset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            buckets[day] = (minutes: 0, sessions: 0)
        }

        for session in sessions {
            guard var bucket = buckets[session.dayBucket] else { continue }
            bucket.minutes += session.focusMinutes
            bucket.sessions += 1
            buckets[session.dayBucket] = bucket
        }

        weeklySummaries = buckets
            .map { key, value in
                DailyFocusSummary(day: key, totalMinutes: value.minutes, sessionCount: value.sessions)
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
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previousDay
        }

        currentStreak = streak
    }
}
