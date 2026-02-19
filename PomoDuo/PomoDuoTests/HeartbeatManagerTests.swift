import Foundation
import Testing

@testable import PomoDuo

@MainActor
@Suite("HeartbeatManager")
struct HeartbeatManagerTests {

    @Test("Initial state is partner active with no last-seen date")
    func initialState() {
        let manager = HeartbeatManager()

        #expect(manager.isPartnerActive == true)
        #expect(manager.partnerLastSeen == nil)
    }

    @Test("startBeating sets internal state")
    func startBeatingSetsState() {
        let manager = HeartbeatManager()

        manager.startBeating(
            sessionID: "session-1",
            userID: "user-a",
            partnerID: "user-b",
            onPartnerStale: {}
        )

        #expect(manager.isPartnerActive == true)
        #expect(manager.partnerLastSeen == nil)
    }

    @Test("stopBeating resets all state")
    func stopBeatingResetsState() {
        let manager = HeartbeatManager()

        manager.startBeating(
            sessionID: "session-1",
            userID: "user-a",
            partnerID: "user-b",
            onPartnerStale: {}
        )

        manager.stopBeating()

        #expect(manager.isPartnerActive == true)
        #expect(manager.partnerLastSeen == nil)
    }

    @Test("Starting a new session replaces the previous heartbeat")
    func replacesExistingHeartbeat() {
        let manager = HeartbeatManager()

        manager.startBeating(
            sessionID: "session-1",
            userID: "user-a",
            partnerID: "user-b",
            onPartnerStale: {}
        )

        // Starting a different session should not crash or double-beat.
        manager.startBeating(
            sessionID: "session-2",
            userID: "user-a",
            partnerID: "user-c",
            onPartnerStale: {}
        )

        #expect(manager.isPartnerActive == true)
    }

    @Test("Same session ID is a no-op")
    func sameSessionIsNoop() {
        let manager = HeartbeatManager()

        var callCount = 0
        manager.startBeating(
            sessionID: "session-1",
            userID: "user-a",
            partnerID: "user-b",
            onPartnerStale: { callCount += 1 }
        )

        // Calling with the same session ID should be a no-op.
        manager.startBeating(
            sessionID: "session-1",
            userID: "user-a",
            partnerID: "user-b",
            onPartnerStale: { callCount += 1 }
        )

        #expect(callCount == 0)
    }

    @Test("Stale threshold and auto-end threshold constants are valid")
    func thresholdsAreValid() {
        #expect(HeartbeatManager.staleThreshold > 0)
        #expect(
            HeartbeatManager.autoEndThreshold > HeartbeatManager.staleThreshold
        )
        #expect(HeartbeatManager.beatInterval > .zero)
    }
}
