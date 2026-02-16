//
//  SessionManagerIdentityTests.swift
//  PomoDuoTests
//
//  Created by Codex on 2/16/26.
//

import Testing
@testable import PomoDuo

@Suite("SessionManager Identity")
@MainActor
struct SessionManagerIdentityTests {
    @Test("Requesting a session without identity is a no-op")
    func requestWithoutIdentityNoOp() async {
        let manager = SessionManager()

        await manager.requestSession(partnerID: "partner-1")

        #expect(manager.currentSession == nil)
    }

    @Test("Identity is stored for subsequent session actions")
    func setIdentity() {
        let manager = SessionManager()

        manager.setCurrentUserID("user-1")

        #expect(manager.currentUserID == "user-1")
    }

    @Test("Changing identity clears any active local session")
    func changingIdentityClearsSession() async {
        let manager = SessionManager()
        manager.setCurrentUserID("user-1")
        await manager.requestSession(partnerID: "partner-1")
        #expect(manager.currentSession != nil)

        manager.setCurrentUserID("user-2")

        #expect(manager.currentSession == nil)
        #expect(manager.currentUserID == "user-2")
    }
}
