import Foundation
import Testing

@testable import PomoDuo

/// Regression tests for the single-session rule: solo and paired focus
/// sessions must not run simultaneously.
@Suite("Session Conflict Prevention")
@MainActor
struct SessionConflictTests {

    // MARK: - hasActivePairedSession

    @Test("hasActivePairedSession is false when no session exists")
    func noSessionMeansNoPairedSession() {
        let manager = SessionManager()
        #expect(!manager.hasActivePairedSession)
    }

    @Test("hasActivePairedSession is true during requesting state")
    func requestingBlocksSolo() async {
        let manager = makeAuthenticatedManager()
        await manager.requestSession(partnerID: "partner-1")

        #expect(manager.currentSession?.state == .requesting)
        #expect(manager.hasActivePairedSession)
    }

    @Test("hasActivePairedSession is true during focus state")
    func focusBlocksSolo() async {
        let manager = makeAuthenticatedManager()
        await manager.requestSession(partnerID: "partner-1")
        await manager.acceptSession()

        #expect(manager.currentSession?.state == .focus)
        #expect(manager.hasActivePairedSession)
    }

    @Test("hasActivePairedSession is true during paused focus")
    func pausedFocusBlocksSolo() async {
        let manager = makeAuthenticatedManager()
        await manager.requestSession(partnerID: "partner-1")
        await manager.acceptSession()
        await manager.pause()

        #expect(manager.currentSession?.isPaused == true)
        #expect(manager.hasActivePairedSession)
    }

    @Test("hasActivePairedSession is true during short break")
    func shortBreakBlocksSolo() async {
        let manager = makeAuthenticatedManager()
        await manager.requestSession(partnerID: "partner-1")
        await manager.acceptSession()
        await manager.beginBreak()

        #expect(manager.currentSession?.state == .shortBreak)
        #expect(manager.hasActivePairedSession)
    }

    @Test("hasActivePairedSession is true during long break")
    func longBreakBlocksSolo() async {
        let manager = makeAuthenticatedManager()
        await manager.requestSession(
            partnerID: "partner-1",
            totalRounds: 1
        )
        await manager.acceptSession()
        await manager.beginBreak()

        #expect(manager.currentSession?.state == .longBreak)
        #expect(manager.hasActivePairedSession)
    }

    @Test("hasActivePairedSession is false after session completes")
    func completedDoesNotBlockSolo() async {
        let manager = makeAuthenticatedManager()
        await manager.requestSession(partnerID: "partner-1")
        await manager.acceptSession()
        await manager.completeSession()

        #expect(manager.currentSession?.state == .completed)
        #expect(!manager.hasActivePairedSession)
    }

    @Test("hasActivePairedSession is false after session is cleared")
    func clearedDoesNotBlockSolo() async {
        let manager = makeAuthenticatedManager()
        await manager.requestSession(partnerID: "partner-1")
        await manager.clearSession()

        #expect(manager.currentSession == nil)
        #expect(!manager.hasActivePairedSession)
    }

    // MARK: - Symmetry: paired side still blocks on solo

    @Test("PartnerSessionViewModel blocks start when solo session exists")
    func pairedBlockedBySolo() async {
        let store = SoloTimerSessionStore(
            userDefaults: UserDefaults(suiteName: "conflict-test-paired-\(UUID())")
        )
        store.save(
            SoloTimerSessionSnapshot(
                phase: .focus,
                currentRound: 1,
                focusStartedAt: .now,
                targetEndDate: .now.addingTimeInterval(25 * 60),
                phaseDuration: 25 * 60,
                status: .running,
                pausedRemainingSeconds: 0
            )
        )

        let manager = makeAuthenticatedManager()
        let viewModel = PartnerSessionViewModel(
            sessionManager: manager,
            soloSessionStore: store
        )

        let partner = PartnerProfile(
            id: "partner-1",
            displayName: "Study Buddy",
            pairedAt: .now
        )
        await viewModel.startSession(with: partner)

        #expect(viewModel.isShowingSoloSessionConflict)
        #expect(viewModel.activeSession == nil)

        store.clear()
    }

    // MARK: - Helpers

    private func makeAuthenticatedManager() -> SessionManager {
        let manager = SessionManager(syncService: MockSessionSyncService())
        manager.setCurrentUserID("user-1")
        return manager
    }
}
