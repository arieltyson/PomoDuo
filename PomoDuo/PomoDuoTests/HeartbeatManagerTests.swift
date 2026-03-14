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

    @Test("Recent partner heartbeat keeps the partner active")
    func recentPartnerHeartbeatKeepsPartnerActive() async {
        let manager = HeartbeatManager()

        manager.startBeating(
            sessionID: "session-1",
            userID: "user-a",
            partnerID: "user-b",
            onPartnerStale: {}
        )

        let heartbeatDate = Date.now.addingTimeInterval(-30)
        await manager.ingestPartnerHeartbeat(
            heartbeatDate,
            referenceDate: .now
        )

        #expect(manager.isPartnerActive == true)
        #expect(manager.partnerLastSeen == heartbeatDate)
    }

    @Test("Stale partner heartbeat marks the partner inactive")
    func stalePartnerHeartbeatMarksPartnerInactive() async {
        let manager = HeartbeatManager()

        manager.startBeating(
            sessionID: "session-1",
            userID: "user-a",
            partnerID: "user-b",
            onPartnerStale: {}
        )

        let referenceDate = Date.now
        let heartbeatDate = referenceDate.addingTimeInterval(
            -(HeartbeatManager.staleThreshold + 30)
        )
        await manager.ingestPartnerHeartbeat(
            heartbeatDate,
            referenceDate: referenceDate
        )

        #expect(manager.isPartnerActive == false)
        #expect(manager.partnerLastSeen == heartbeatDate)
    }

    @Test("Auto-end heartbeat threshold triggers the callback once")
    func autoEndThresholdTriggersCallbackOnce() async {
        let manager = HeartbeatManager()
        let referenceDate = Date.now
        let heartbeatDate = referenceDate.addingTimeInterval(
            -(HeartbeatManager.autoEndThreshold + 30)
        )
        var callCount = 0

        manager.startBeating(
            sessionID: "session-1",
            userID: "user-a",
            partnerID: "user-b",
            onPartnerStale: { callCount += 1 }
        )

        await manager.ingestPartnerHeartbeat(
            heartbeatDate,
            referenceDate: referenceDate
        )
        await manager.ingestPartnerHeartbeat(
            heartbeatDate,
            referenceDate: referenceDate
        )

        #expect(manager.isPartnerActive == false)
        #expect(callCount == 1)
    }
}
