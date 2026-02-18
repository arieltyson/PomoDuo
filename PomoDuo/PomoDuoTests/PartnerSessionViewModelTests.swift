//
//  PartnerSessionViewModelTests.swift
//  PomoDuoTests
//
//  Created by Codex on 2/16/26.
//

import Foundation
import Testing
@testable import PomoDuo

@Suite("PartnerSessionViewModel")
@MainActor
struct PartnerSessionViewModelTests {
    private let testPartner = PartnerProfile(
        id: "partner-1",
        displayName: "Study Buddy",
        pairedAt: .now
    )

    private func makeSessionManager(authenticated: Bool = true) -> SessionManager {
        let manager = SessionManager(syncService: MockSessionSyncService())
        if authenticated {
            manager.setCurrentUserID("user-1")
        }
        return manager
    }

    private func makeViewModel(
        manager: SessionManager
    ) -> PartnerSessionViewModel {
        PartnerSessionViewModel(sessionManager: manager)
    }

    @Test("Initial state has no active paired session")
    func initialState() {
        let manager = makeSessionManager()
        let viewModel = makeViewModel(manager: manager)

        #expect(viewModel.activeSession == nil)
        #expect(!viewModel.hasActiveSession)
        #expect(!viewModel.isStartingSession)
        #expect(!viewModel.isWaitingForAcceptance)
        #expect(!viewModel.isIncomingRequest)
        #expect(!viewModel.isFocusing)
        #expect(!viewModel.isPaused)
        #expect(!viewModel.isOnBreak)
        #expect(!viewModel.isCompleted)
        #expect(viewModel.sessionError == nil)
    }

    @Test("incoming request state is true only for partner B")
    func incomingRequestState() async {
        let manager = makeSessionManager()
        let viewModel = makeViewModel(manager: manager)

        await manager.requestSession(partnerID: "partner-1")
        #expect(!viewModel.isIncomingRequest)

        let incoming = StudySession(
            id: "incoming-request",
            partnerA: "partner-1",
            partnerB: "user-1",
            state: .requesting,
            startTime: .now,
            targetEndDate: .now.addingTimeInterval(25 * 60),
            duration: 25 * 60,
            isPaused: false,
            pausedBy: nil,
            currentRound: 1,
            totalRounds: 4
        )
        await manager.handleRemoteUpdate(incoming)

        #expect(viewModel.isIncomingRequest)
        #expect(!viewModel.isWaitingForAcceptance)
    }

    @Test("acceptIncomingSession transitions request to focus")
    func acceptIncomingSession() async {
        let manager = makeSessionManager()
        let viewModel = makeViewModel(manager: manager)

        await manager.handleRemoteUpdate(
            StudySession(
                id: "incoming-accept",
                partnerA: "partner-1",
                partnerB: "user-1",
                state: .requesting,
                startTime: .now,
                targetEndDate: .now.addingTimeInterval(25 * 60),
                duration: 25 * 60,
                isPaused: false,
                pausedBy: nil,
                currentRound: 1,
                totalRounds: 4
            )
        )

        await viewModel.acceptIncomingSession()

        #expect(viewModel.activeSession?.state == .focus)
        #expect(viewModel.sessionError == nil)
    }

    @Test("declineIncomingSession clears local session")
    func declineIncomingSession() async {
        let manager = makeSessionManager()
        let viewModel = makeViewModel(manager: manager)

        await manager.handleRemoteUpdate(
            StudySession(
                id: "incoming-decline",
                partnerA: "partner-1",
                partnerB: "user-1",
                state: .requesting,
                startTime: .now,
                targetEndDate: .now.addingTimeInterval(25 * 60),
                duration: 25 * 60,
                isPaused: false,
                pausedBy: nil,
                currentRound: 1,
                totalRounds: 4
            )
        )

        await viewModel.declineIncomingSession()

        #expect(viewModel.activeSession == nil)
        #expect(viewModel.sessionError == nil)
    }

    @Test("startSession creates a requesting session")
    func startSession() async {
        let manager = makeSessionManager()
        let viewModel = makeViewModel(manager: manager)

        await viewModel.startSession(with: testPartner)

        #expect(viewModel.hasActiveSession)
        #expect(viewModel.isWaitingForAcceptance)
        #expect(viewModel.activeSession?.state == .requesting)
        #expect(!viewModel.isStartingSession)
    }

    @Test("startSession honors provided duration and rounds")
    func startSessionHonorsProvidedConfiguration() async {
        let manager = makeSessionManager()
        let viewModel = makeViewModel(manager: manager)
        let configuredDuration = TimeInterval(45 * 60)
        let configuredRounds = 6

        await viewModel.startSession(
            with: testPartner,
            duration: configuredDuration,
            totalRounds: configuredRounds
        )

        #expect(viewModel.activeSession?.duration == configuredDuration)
        #expect(viewModel.activeSession?.totalRounds == configuredRounds)
    }

    @Test("startSession requires an authenticated user")
    func startSessionRequiresAuth() async {
        let manager = makeSessionManager(authenticated: false)
        let viewModel = makeViewModel(manager: manager)

        await viewModel.startSession(with: testPartner)

        #expect(viewModel.activeSession == nil)
        #expect(viewModel.sessionError != nil)
    }

    @Test("startSession is ignored while a session is already active")
    func startSessionGuard() async {
        let manager = makeSessionManager()
        let viewModel = makeViewModel(manager: manager)

        await viewModel.startSession(with: testPartner)
        let firstSessionID = viewModel.activeSession?.id

        await viewModel.startSession(with: testPartner)

        #expect(viewModel.activeSession?.id == firstSessionID)
    }

    @Test("pauseSession pauses active focus")
    func pauseSession() async {
        let manager = makeSessionManager()
        let viewModel = makeViewModel(manager: manager)

        await viewModel.startSession(with: testPartner)
        await manager.acceptSession()

        await viewModel.pauseSession()

        #expect(viewModel.isPaused)
        #expect(viewModel.activeSession?.isPaused == true)
    }

    @Test("resumeSession resumes from paused focus")
    func resumeSession() async {
        let manager = makeSessionManager()
        let viewModel = makeViewModel(manager: manager)

        await viewModel.startSession(with: testPartner)
        await manager.acceptSession()
        await viewModel.pauseSession()

        await viewModel.resumeSession()

        #expect(viewModel.isFocusing)
        #expect(viewModel.activeSession?.isPaused == false)
    }

    @Test("beginBreak transitions from focus into break")
    func beginBreak() async {
        let manager = makeSessionManager()
        let viewModel = makeViewModel(manager: manager)

        await viewModel.startSession(with: testPartner)
        await manager.acceptSession()

        await viewModel.beginBreak()

        #expect(viewModel.isOnBreak)
    }

    @Test("beginFocus transitions from break to next round")
    func beginFocus() async {
        let manager = makeSessionManager()
        let viewModel = makeViewModel(manager: manager)

        await viewModel.startSession(with: testPartner)
        await manager.acceptSession()
        await viewModel.beginBreak()

        await viewModel.beginFocus()

        #expect(viewModel.isFocusing)
        #expect(viewModel.activeSession?.currentRound == 2)
    }

    @Test("endSession from requesting declines and clears")
    func endFromRequesting() async {
        let manager = makeSessionManager()
        let viewModel = makeViewModel(manager: manager)

        await viewModel.startSession(with: testPartner)

        await viewModel.endSession()

        #expect(viewModel.activeSession == nil)
        #expect(!viewModel.hasActiveSession)
    }

    @Test("endSession from focus completes but keeps completed state")
    func endFromFocus() async {
        let manager = makeSessionManager()
        let viewModel = makeViewModel(manager: manager)

        await viewModel.startSession(with: testPartner)
        await manager.acceptSession()

        await viewModel.endSession()

        #expect(viewModel.isCompleted)
        #expect(viewModel.activeSession?.state == .completed)
    }

    @Test("endSession from completed clears session")
    func endFromCompleted() async {
        let manager = makeSessionManager()
        let viewModel = makeViewModel(manager: manager)

        await viewModel.startSession(with: testPartner)
        await manager.acceptSession()
        await viewModel.endSession()

        await viewModel.endSession()

        #expect(viewModel.activeSession == nil)
        #expect(!viewModel.hasActiveSession)
    }

    @Test("endSession from short break clears session")
    func endFromShortBreak() async {
        let manager = makeSessionManager()
        let viewModel = makeViewModel(manager: manager)

        await viewModel.startSession(with: testPartner)
        await manager.acceptSession()
        await viewModel.beginBreak()

        await viewModel.endSession()

        #expect(viewModel.activeSession == nil)
    }

    @Test("endSession from long break marks completed")
    func endFromLongBreak() async {
        let manager = makeSessionManager()
        let viewModel = makeViewModel(manager: manager)

        await viewModel.startSession(with: testPartner, totalRounds: 1)
        await manager.acceptSession()
        await viewModel.beginBreak()

        #expect(viewModel.activeSession?.state == .longBreak)

        await viewModel.endSession()

        #expect(viewModel.activeSession?.state == .completed)
    }

    @Test("reset clears local operation state")
    func reset() async {
        let manager = makeSessionManager()
        let viewModel = makeViewModel(manager: manager)

        await viewModel.startSession(with: testPartner)
        viewModel.reset()

        #expect(!viewModel.isStartingSession)
        #expect(viewModel.sessionError == nil)
    }
}

@Suite("SessionManager clearSession")
@MainActor
struct SessionManagerClearSessionTests {
    @Test("clearSession removes local active session")
    func clearSession() async {
        let manager = SessionManager(syncService: MockSessionSyncService())
        manager.setCurrentUserID("user-1")

        await manager.requestSession(partnerID: "partner-1")
        #expect(manager.currentSession != nil)

        await manager.clearSession()

        #expect(manager.currentSession == nil)
        #expect(manager.lastError == nil)
    }

    @Test("clearSession deletes the session document from sync service")
    func clearSessionDeletesRemote() async {
        let syncService = MockSessionSyncService()
        let manager = SessionManager(syncService: syncService)
        manager.setCurrentUserID("user-1")

        await manager.requestSession(partnerID: "partner-1")
        let sessionID = manager.currentSession?.id

        await manager.clearSession()

        guard let sessionID else {
            Issue.record("Expected an active session ID before clearSession")
            return
        }

        let stored = await syncService.session(for: sessionID)
        #expect(stored == nil)
    }

    @Test("clearSession is a safe no-op when no session exists")
    func clearSessionNoOp() async {
        let manager = SessionManager(syncService: MockSessionSyncService())

        await manager.clearSession()

        #expect(manager.currentSession == nil)
        #expect(manager.lastError == nil)
    }
}
