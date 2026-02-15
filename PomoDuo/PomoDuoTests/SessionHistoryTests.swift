//
//  SessionHistoryTests.swift
//  PomoDuoTests
//
//  Created by Codex on 2/15/26.
//

import Foundation
import Testing
@testable import PomoDuo

struct CompletedSessionTests {
    @Test func defaultInitializationValues() {
        let session = CompletedSession(
            focusDuration: 25 * 60,
            roundNumber: 1,
            totalRounds: 4
        )

        #expect(session.focusDuration == 25 * 60)
        #expect(session.roundNumber == 1)
        #expect(session.totalRounds == 4)
        #expect(session.sessionType == .solo)
        #expect(session.focusMinutes == 25)
    }

    @Test func focusMinutesHasMinimumOfOne() {
        let session = CompletedSession(
            focusDuration: 30,
            roundNumber: 1,
            totalRounds: 4
        )

        #expect(session.focusMinutes == 1)
    }

    @Test func dayBucketUsesStartOfDay() {
        let calendar = Calendar.current
        let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)

        let session = CompletedSession(
            startedAt: referenceDate,
            focusDuration: 25 * 60,
            roundNumber: 1,
            totalRounds: 4
        )

        #expect(session.dayBucket == calendar.startOfDay(for: referenceDate))
    }

    @Test func pairedSessionTypePersists() {
        let session = CompletedSession(
            focusDuration: 25 * 60,
            roundNumber: 1,
            totalRounds: 4,
            sessionType: .paired
        )

        #expect(session.sessionType == .paired)
    }
}

@MainActor
struct DailyFocusSummaryTests {
    @Test func idMatchesDay() {
        let day = Date.now
        let summary = DailyFocusSummary(day: day, totalMinutes: 60, sessionCount: 2)

        #expect(summary.id == day)
    }

    @Test func dayLabelIsNotEmpty() {
        let summary = DailyFocusSummary(day: .now, totalMinutes: 25, sessionCount: 1)
        #expect(summary.dayLabel.isEmpty == false)
    }
}

@MainActor
struct SessionHistoryViewModelTests {
    @Test func emptyInputProducesZeroStatsAndSevenDays() {
        let viewModel = SessionHistoryViewModel()
        viewModel.refresh(from: [])

        #expect(viewModel.allTimeFocusMinutes == 0)
        #expect(viewModel.allTimeSessionCount == 0)
        #expect(viewModel.currentStreak == 0)
        #expect(viewModel.weeklySummaries.count == 7)
    }

    @Test func singleSessionProducesExpectedStats() {
        let session = CompletedSession(
            startedAt: .now,
            focusDuration: 25 * 60,
            roundNumber: 1,
            totalRounds: 4
        )

        let viewModel = SessionHistoryViewModel()
        viewModel.refresh(from: [session])

        #expect(viewModel.allTimeFocusMinutes == 25)
        #expect(viewModel.allTimeSessionCount == 1)
        #expect(viewModel.currentStreak == 1)
    }

    @Test func multipleSameDaySessionsAggregateIntoOneBar() {
        let sessions = (1...3).map { round in
            CompletedSession(
                startedAt: .now,
                focusDuration: 25 * 60,
                roundNumber: round,
                totalRounds: 4
            )
        }

        let viewModel = SessionHistoryViewModel()
        viewModel.refresh(from: sessions)

        #expect(viewModel.allTimeFocusMinutes == 75)
        #expect(viewModel.allTimeSessionCount == 3)

        let today = Calendar.current.startOfDay(for: .now)
        let todaySummary = viewModel.weeklySummaries.first { $0.day == today }
        #expect(todaySummary?.totalMinutes == 75)
        #expect(todaySummary?.sessionCount == 3)
    }

    @Test func weeklySummariesStayChronological() {
        let viewModel = SessionHistoryViewModel()
        viewModel.refresh(from: [])

        for index in 0..<(viewModel.weeklySummaries.count - 1) {
            #expect(viewModel.weeklySummaries[index].day < viewModel.weeklySummaries[index + 1].day)
        }
    }

    @Test func streakCountsConsecutiveDaysBackFromToday() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        var sessions: [CompletedSession] = []
        for offset in 0..<3 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            sessions.append(
                CompletedSession(
                    startedAt: day.addingTimeInterval(3600),
                    focusDuration: 25 * 60,
                    roundNumber: 1,
                    totalRounds: 4
                )
            )
        }

        let viewModel = SessionHistoryViewModel()
        viewModel.refresh(from: sessions)

        #expect(viewModel.currentStreak == 3)
    }

    @Test func streakStopsAtFirstMissingDay() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        var sessions: [CompletedSession] = [
            CompletedSession(
                startedAt: today.addingTimeInterval(600),
                focusDuration: 25 * 60,
                roundNumber: 1,
                totalRounds: 4
            )
        ]

        if let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today) {
            sessions.append(
                CompletedSession(
                    startedAt: twoDaysAgo.addingTimeInterval(600),
                    focusDuration: 25 * 60,
                    roundNumber: 1,
                    totalRounds: 4
                )
            )
        }

        let viewModel = SessionHistoryViewModel()
        viewModel.refresh(from: sessions)

        #expect(viewModel.currentStreak == 1)
    }

    @Test func oldSessionsExcludedFromWeeklyIncludedInAllTime() {
        let calendar = Calendar.current
        guard let oldDate = calendar.date(byAdding: .day, value: -10, to: .now) else {
            Issue.record("Failed to create test date")
            return
        }

        let session = CompletedSession(
            startedAt: oldDate,
            focusDuration: 30 * 60,
            roundNumber: 1,
            totalRounds: 4
        )

        let viewModel = SessionHistoryViewModel()
        viewModel.refresh(from: [session])

        #expect(viewModel.allTimeFocusMinutes == 30)
        #expect(viewModel.allTimeSessionCount == 1)
        #expect(viewModel.currentStreak == 0)

        let weeklyTotal = viewModel.weeklySummaries.reduce(0) { partial, item in
            partial + item.totalMinutes
        }
        #expect(weeklyTotal == 0)
    }
}
