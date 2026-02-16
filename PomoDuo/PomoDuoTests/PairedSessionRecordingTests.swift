//
//  PairedSessionRecordingTests.swift
//  PomoDuoTests
//
//  Created by Codex on 2/16/26.
//

import Foundation
import Testing
@testable import PomoDuo

@Suite("CompletedSession Paired Recording")
struct CompletedSessionPairedTests {

    @Test("Paired session records with paired type")
    func pairedSessionType() {
        let session = CompletedSession(
            startedAt: .now,
            focusDuration: 25 * 60,
            roundNumber: 1,
            totalRounds: 4,
            sessionType: .paired,
            userID: "user-1"
        )

        #expect(session.sessionType == .paired)
        #expect(session.userID == "user-1")
        #expect(session.focusMinutes == 25)
        #expect(session.roundNumber == 1)
        #expect(session.totalRounds == 4)
    }

    @Test("Solo session records with solo type")
    func soloSessionType() {
        let session = CompletedSession(
            startedAt: .now,
            focusDuration: 25 * 60,
            roundNumber: 2,
            totalRounds: 4,
            sessionType: .solo,
            userID: "user-1"
        )

        #expect(session.sessionType == .solo)
    }

    @Test("Default session type is solo")
    func defaultSessionType() {
        let session = CompletedSession(
            startedAt: .now,
            focusDuration: 25 * 60,
            roundNumber: 1,
            totalRounds: 4
        )

        #expect(session.sessionType == .solo)
    }

    @Test("Session type supports codable round trip")
    func sessionTypeCodable() throws {
        let original = CompletedSession.SessionType.paired
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CompletedSession.SessionType.self, from: encoded)

        #expect(decoded == .paired)
    }

    @Test("Day bucket is computed from startedAt")
    func dayBucketComputed() {
        let calendar = Calendar.current
        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: .now) ?? .now

        let session = CompletedSession(
            startedAt: noon,
            focusDuration: 25 * 60,
            roundNumber: 1,
            totalRounds: 4,
            sessionType: .paired
        )

        #expect(session.dayBucket == calendar.startOfDay(for: noon))
    }

    @Test("Focus minutes rounds down with minimum one minute")
    func focusMinutesRounding() {
        let veryShortSession = CompletedSession(
            startedAt: .now,
            focusDuration: 30,
            roundNumber: 1,
            totalRounds: 4,
            sessionType: .paired
        )

        #expect(veryShortSession.focusMinutes == 1)

        let longSession = CompletedSession(
            startedAt: .now,
            focusDuration: 50 * 60,
            roundNumber: 1,
            totalRounds: 4,
            sessionType: .paired
        )

        #expect(longSession.focusMinutes == 50)
    }
}

@Suite("Paired Session Lifecycle")
@MainActor
struct PairedSessionLifecycleTests {
    private let testPartner = PartnerProfile(
        id: "partner-1",
        displayName: "Study Buddy",
        pairedAt: .now
    )

    private func makeSessionManager() -> SessionManager {
        let manager = SessionManager(syncService: MockSessionSyncService())
        manager.setCurrentUserID("user-1")
        return manager
    }

    @Test("Session lifecycle reaches expected states")
    func fullFocusCycle() async {
        let manager = makeSessionManager()
        let viewModel = PartnerSessionViewModel(
            sessionManager: manager,
            autoAcceptDelay: .seconds(60)
        )

        await viewModel.startSession(with: testPartner)
        await manager.acceptSession()

        #expect(viewModel.activeSession?.state == .focus)
        #expect(viewModel.activeSession?.currentRound == 1)

        await viewModel.beginBreak()
        #expect(viewModel.isOnBreak)

        await viewModel.beginFocus()
        #expect(viewModel.activeSession?.state == .focus)
        #expect(viewModel.activeSession?.currentRound == 2)
    }

    @Test("Custom duration and round count propagate to session")
    func durationPropagation() async {
        let manager = makeSessionManager()
        let viewModel = PartnerSessionViewModel(
            sessionManager: manager,
            autoAcceptDelay: .seconds(60)
        )

        await viewModel.startSession(with: testPartner, duration: 50 * 60, totalRounds: 6)
        await manager.acceptSession()

        #expect(viewModel.activeSession?.duration == 50 * 60)
        #expect(viewModel.activeSession?.totalRounds == 6)
    }

    @Test("Final round transitions to long break")
    func finalRoundLongBreak() async {
        let manager = makeSessionManager()
        let viewModel = PartnerSessionViewModel(
            sessionManager: manager,
            autoAcceptDelay: .seconds(60)
        )

        await viewModel.startSession(with: testPartner, totalRounds: 1)
        await manager.acceptSession()
        await viewModel.beginBreak()

        #expect(viewModel.activeSession?.state == .longBreak)
    }

    @Test("Non-final round transitions to short break")
    func nonFinalRoundShortBreak() async {
        let manager = makeSessionManager()
        let viewModel = PartnerSessionViewModel(
            sessionManager: manager,
            autoAcceptDelay: .seconds(60)
        )

        await viewModel.startSession(with: testPartner, totalRounds: 4)
        await manager.acceptSession()
        await viewModel.beginBreak()

        #expect(viewModel.activeSession?.state == .shortBreak)
    }
}

@Suite("AppTab History")
struct AppTabHistoryTests {

    @Test("History tab exists")
    func historyTabExists() {
        #expect(AppTab.allCases.contains(.history))
    }

    @Test("History tab metadata is correct")
    func historyMetadata() {
        #expect(AppTab.history.title == "History")
        #expect(AppTab.history.systemImage == "clock.arrow.circlepath")
    }

    @Test("Tab ordering includes history between partner and settings")
    func tabOrdering() {
        #expect(AppTab.allCases == [.timer, .partner, .history, .settings])
    }
}
