//
//  SessionHistoryFilterTests.swift
//  PomoDuoTests
//
//  Created by Codex on 2/16/26.
//

import Foundation
import Testing
@testable import PomoDuo

@Suite("SessionTypeFilter")
struct SessionTypeFilterSuiteTests {

    @Test("allCases includes all/solo/paired")
    func allCases() {
        #expect(SessionTypeFilter.allCases == [.all, .solo, .paired])
    }

    @Test("Titles are correct")
    func titles() {
        #expect(SessionTypeFilter.all.title == "All")
        #expect(SessionTypeFilter.solo.title == "Solo")
        #expect(SessionTypeFilter.paired.title == "Paired")
    }

    @Test("IDs match raw values")
    func ids() {
        #expect(SessionTypeFilter.all.id == "all")
        #expect(SessionTypeFilter.solo.id == "solo")
        #expect(SessionTypeFilter.paired.id == "paired")
    }
}

@Suite("SessionHistory Filtering")
@MainActor
struct SessionHistoryFilteringSuiteTests {

    private func makeSession(
        type: CompletedSession.SessionType,
        userID: String = "user-1",
        minutes: Int = 25,
        startedAt: Date = .now
    ) -> CompletedSession {
        CompletedSession(
            startedAt: startedAt,
            focusDuration: TimeInterval(minutes * 60),
            roundNumber: 1,
            totalRounds: 4,
            sessionType: type,
            userID: userID
        )
    }

    @Test("Default active filter is all")
    func defaultFilter() {
        let viewModel = SessionHistoryViewModel()
        #expect(viewModel.activeFilter == .all)
    }

    @Test("All filter returns all sessions")
    func allFilter() {
        let viewModel = SessionHistoryViewModel()
        viewModel.activeFilter = .all

        let sessions = [
            makeSession(type: .solo),
            makeSession(type: .paired)
        ]

        let filtered = viewModel.filteredSessions(from: sessions)
        #expect(filtered.count == 2)
    }

    @Test("Solo filter returns only solo sessions")
    func soloFilter() {
        let viewModel = SessionHistoryViewModel()
        viewModel.activeFilter = .solo

        let sessions = [
            makeSession(type: .solo),
            makeSession(type: .paired),
            makeSession(type: .solo)
        ]

        let filtered = viewModel.filteredSessions(from: sessions)
        #expect(filtered.count == 2)
        #expect(filtered.allSatisfy { $0.sessionType == .solo })
    }

    @Test("Paired filter returns only paired sessions")
    func pairedFilter() {
        let viewModel = SessionHistoryViewModel()
        viewModel.activeFilter = .paired

        let sessions = [
            makeSession(type: .solo),
            makeSession(type: .paired),
            makeSession(type: .paired)
        ]

        let filtered = viewModel.filteredSessions(from: sessions)
        #expect(filtered.count == 2)
        #expect(filtered.allSatisfy { $0.sessionType == .paired })
    }

    @Test("Paired filter can return empty")
    func pairedFilterEmpty() {
        let viewModel = SessionHistoryViewModel()
        viewModel.activeFilter = .paired

        let sessions = [makeSession(type: .solo)]
        let filtered = viewModel.filteredSessions(from: sessions)
        #expect(filtered.isEmpty)
    }
}

@Suite("SessionHistory Paired Stats")
@MainActor
struct SessionHistoryPairedStatsSuiteTests {

    private func makeSession(
        type: CompletedSession.SessionType,
        userID: String = "user-1",
        minutes: Int = 25,
        startedAt: Date = .now
    ) -> CompletedSession {
        CompletedSession(
            startedAt: startedAt,
            focusDuration: TimeInterval(minutes * 60),
            roundNumber: 1,
            totalRounds: 4,
            sessionType: type,
            userID: userID
        )
    }

    @Test("Refresh computes solo and paired stats separately")
    func pairedAndSoloStats() {
        let viewModel = SessionHistoryViewModel()
        let sessions = [
            makeSession(type: .solo, minutes: 25),
            makeSession(type: .solo, minutes: 50),
            makeSession(type: .paired, minutes: 30)
        ]

        viewModel.refresh(from: sessions, userID: "user-1")

        #expect(viewModel.soloSessionCount == 2)
        #expect(viewModel.soloFocusMinutes == 75)
        #expect(viewModel.pairedSessionCount == 1)
        #expect(viewModel.pairedFocusMinutes == 30)

        #expect(viewModel.allTimeSessionCount == 3)
        #expect(viewModel.allTimeFocusMinutes == 105)
    }

    @Test("Empty refresh zeros paired stats")
    func emptyPairedStats() {
        let viewModel = SessionHistoryViewModel()
        viewModel.refresh(from: [])

        #expect(viewModel.soloSessionCount == 0)
        #expect(viewModel.soloFocusMinutes == 0)
        #expect(viewModel.pairedSessionCount == 0)
        #expect(viewModel.pairedFocusMinutes == 0)
    }

    @Test("Solo-only sessions keep paired stats at zero")
    func soloOnly() {
        let viewModel = SessionHistoryViewModel()
        let sessions = [
            makeSession(type: .solo, minutes: 20),
            makeSession(type: .solo, minutes: 40)
        ]

        viewModel.refresh(from: sessions, userID: "user-1")

        #expect(viewModel.soloSessionCount == 2)
        #expect(viewModel.soloFocusMinutes == 60)
        #expect(viewModel.pairedSessionCount == 0)
        #expect(viewModel.pairedFocusMinutes == 0)
    }

    @Test("Paired-only sessions keep solo stats at zero")
    func pairedOnly() {
        let viewModel = SessionHistoryViewModel()
        let sessions = [
            makeSession(type: .paired, minutes: 30),
            makeSession(type: .paired, minutes: 45)
        ]

        viewModel.refresh(from: sessions, userID: "user-1")

        #expect(viewModel.pairedSessionCount == 2)
        #expect(viewModel.pairedFocusMinutes == 75)
        #expect(viewModel.soloSessionCount == 0)
        #expect(viewModel.soloFocusMinutes == 0)
    }
}

@Suite("SessionHistory Weekly Breakdown")
@MainActor
struct SessionHistoryWeeklyBreakdownSuiteTests {

    @Test("Weekly summary captures solo and paired minutes")
    func weeklyBreakdown() {
        let viewModel = SessionHistoryViewModel()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        let sessions = [
            CompletedSession(
                startedAt: today.addingTimeInterval(60),
                focusDuration: 25 * 60,
                roundNumber: 1,
                totalRounds: 4,
                sessionType: .solo,
                userID: "user-1"
            ),
            CompletedSession(
                startedAt: today.addingTimeInterval(120),
                focusDuration: 30 * 60,
                roundNumber: 1,
                totalRounds: 4,
                sessionType: .paired,
                userID: "user-1"
            )
        ]

        viewModel.refresh(from: sessions, userID: "user-1")

        let todaySummary = viewModel.weeklySummaries.first {
            calendar.isDate($0.day, inSameDayAs: today)
        }

        #expect(todaySummary?.soloMinutes == 25)
        #expect(todaySummary?.pairedMinutes == 30)
        #expect(todaySummary?.totalMinutes == 55)
    }

    @Test("Days with no sessions stay zeroed")
    func emptyDays() {
        let viewModel = SessionHistoryViewModel()
        viewModel.refresh(from: [])

        #expect(viewModel.weeklySummaries.count == 7)
        for summary in viewModel.weeklySummaries {
            #expect(summary.totalMinutes == 0)
            #expect(summary.soloMinutes == 0)
            #expect(summary.pairedMinutes == 0)
        }
    }
}

@Suite("DailyFocusSummary Compatibility")
@MainActor
struct DailyFocusSummaryCompatibilitySuiteTests {

    @Test("Legacy initializer defaults split to zero")
    func legacyInit() {
        let summary = DailyFocusSummary(day: .now, totalMinutes: 50, sessionCount: 2)
        #expect(summary.soloMinutes == 0)
        #expect(summary.pairedMinutes == 0)
    }

    @Test("Extended initializer preserves values")
    func extendedInit() {
        let summary = DailyFocusSummary(
            day: .now,
            totalMinutes: 55,
            sessionCount: 3,
            soloMinutes: 25,
            pairedMinutes: 30
        )

        #expect(summary.totalMinutes == 55)
        #expect(summary.sessionCount == 3)
        #expect(summary.soloMinutes == 25)
        #expect(summary.pairedMinutes == 30)
    }

    @Test("Day label is non-empty")
    func dayLabel() {
        let summary = DailyFocusSummary(day: .now, totalMinutes: 0, sessionCount: 0)
        #expect(!summary.dayLabel.isEmpty)
    }
}
