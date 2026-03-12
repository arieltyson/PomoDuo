import Foundation
import Testing

@testable import PomoDuo

@Suite("SoloTimerSessionStore")
struct SoloTimerSessionStoreTests {
    @Test("save and load round-trips the snapshot")
    func saveAndLoadSnapshot() {
        let suiteName = "SoloTimerSessionStoreTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Failed to create isolated defaults suite.")
            return
        }
        let store = SoloTimerSessionStore(userDefaults: defaults)
        let snapshot = SoloTimerSessionSnapshot(
            phase: .focus,
            currentRound: 2,
            focusStartedAt: .now,
            targetEndDate: .now.addingTimeInterval(25 * 60),
            phaseDuration: 25 * 60,
            status: .paused,
            pausedRemainingSeconds: 12 * 60
        )

        store.save(snapshot)

        #expect(store.load() == snapshot)
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test("clear removes the stored snapshot")
    func clearRemovesSnapshot() {
        let suiteName = "SoloTimerSessionStoreTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Failed to create isolated defaults suite.")
            return
        }
        let store = SoloTimerSessionStore(userDefaults: defaults)
        let snapshot = SoloTimerSessionSnapshot(
            phase: .shortBreak,
            currentRound: 1,
            focusStartedAt: nil,
            targetEndDate: .now.addingTimeInterval(5 * 60),
            phaseDuration: 5 * 60,
            status: .running,
            pausedRemainingSeconds: 0
        )

        store.save(snapshot)
        store.clear()

        #expect(store.load() == nil)
        defaults.removePersistentDomain(forName: suiteName)
    }
}
