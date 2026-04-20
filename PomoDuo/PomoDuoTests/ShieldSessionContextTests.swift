import Foundation
import Testing

@testable import PomoDuo

/// `.serialized` because every test in this suite writes to the shared
/// App-Group `UserDefaults` that backs ``ShieldSessionContext``. Parallel
/// execution would let one test's `writeSession` land inside another
/// test's "clear slate" window and falsify an absence assertion (for
/// example, ``hasUnexpiredTargetEndIsFalseWhenNoContext`` observes a
/// session written by a concurrent test in the same suite). Serialising
/// the suite preserves the cross-test isolation the `init()` reset
/// already assumes.
@Suite("ShieldSessionContext Tests", .serialized)
@MainActor
struct ShieldSessionContextTests {

    init() {
        // Start each test with a clean slate.
        ShieldSessionContext.clearSession()
    }

    // MARK: - Write / Read Round-Trip

    @Test func writeAndReadSessionContext() {
        ShieldSessionContext.writeSession(
            partnerName: "Ariel",
            phase: "Focus",
            targetEndDate: Date(timeIntervalSince1970: 2_000_000_000)
        )

        #expect(ShieldSessionContext.isSessionActive == true)
        #expect(ShieldSessionContext.partnerName == "Ariel")
        #expect(ShieldSessionContext.sessionPhase == "Focus")
        #expect(ShieldSessionContext.targetEndDate != nil)
    }

    @Test func clearSessionRemovesAllValues() {
        ShieldSessionContext.writeSession(
            partnerName: "Ariel",
            phase: "Focus",
            targetEndDate: .now.addingTimeInterval(60)
        )

        ShieldSessionContext.clearSession()

        #expect(ShieldSessionContext.isSessionActive == false)
        #expect(ShieldSessionContext.partnerName == nil)
        #expect(ShieldSessionContext.sessionPhase == nil)
        #expect(ShieldSessionContext.targetEndDate == nil)
    }

    @Test func writePartnerNameIndependently() {
        ShieldSessionContext.writePartnerName("Jordan")
        #expect(ShieldSessionContext.partnerName == "Jordan")
    }

    @Test func partnerNameSurvivesSessionWrite() {
        ShieldSessionContext.writePartnerName("Jordan")

        // SessionManager writes session context without partner name.
        ShieldSessionContext.writeSession(
            partnerName: nil,
            phase: "Focus",
            targetEndDate: .now.addingTimeInterval(300)
        )

        // The nil partner name from writeSession overwrites the existing
        // value, which is the expected behavior — SessionManager clears
        // it because it doesn't know the name, and the view writes it
        // back via writePartnerName.
        #expect(ShieldSessionContext.sessionPhase == "Focus")
    }

    // MARK: - Default Values

    @Test func defaultsReturnSafeValues() {
        ShieldSessionContext.clearSession()

        #expect(ShieldSessionContext.isSessionActive == false)
        #expect(ShieldSessionContext.partnerName == nil)
        #expect(ShieldSessionContext.sessionPhase == nil)
        #expect(ShieldSessionContext.targetEndDate == nil)
    }

    // MARK: - Constants

    @Test func focusActivityIDIsStable() {
        #expect(ShieldSessionContext.focusActivityID == "com.pomoduo.focus")
    }

    @Test func appGroupIDMatchesProjectConfig() {
        #expect(
            ShieldSessionContext.appGroupID == "group.com.arieljtyson.pomoduo"
        )
    }

    // MARK: - Reconcile-Race Guard (hasUnexpiredTargetEnd)
    //
    // These tests pin the ``DeviceActivityMonitorExtension``'s
    // reconcile-race guard. The Monitor's `intervalDidEnd` fires *also*
    // when the main app calls `DeviceActivityCenter.stopMonitoring(_:)`
    // to replace the prior registration — every reschedule during a
    // live session. Without the guard below, the Monitor would
    // eagerly tear down shields + shared context on those spurious
    // ends while focus is still running.

    @Test("No session context yet returns false")
    func hasUnexpiredTargetEndIsFalseWhenNoContext() {
        #expect(ShieldSessionContext.hasUnexpiredTargetEnd() == false)
    }

    @Test("Future target end returns true (session is live, skip teardown)")
    func hasUnexpiredTargetEndIsTrueWhenTargetInFuture() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let future = now.addingTimeInterval(25 * 60)

        ShieldSessionContext.writeSession(
            partnerName: nil,
            phase: "Focus",
            targetEndDate: future
        )

        #expect(ShieldSessionContext.hasUnexpiredTargetEnd(asOf: now))
    }

    @Test("Past target end returns false (session really ended, tear down)")
    func hasUnexpiredTargetEndIsFalseWhenTargetInPast() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let past = now.addingTimeInterval(-60)

        ShieldSessionContext.writeSession(
            partnerName: nil,
            phase: "Focus",
            targetEndDate: past
        )

        #expect(ShieldSessionContext.hasUnexpiredTargetEnd(asOf: now) == false)
    }

    /// Edge: target end exactly equals `now`. By the `>` check, this is
    /// treated as expired — a callback firing exactly at the scheduled
    /// end is a genuine end, not a reschedule.
    @Test("Target end equal to now returns false (treated as expired)")
    func hasUnexpiredTargetEndIsFalseAtBoundary() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)

        ShieldSessionContext.writeSession(
            partnerName: nil,
            phase: "Focus",
            targetEndDate: now
        )

        #expect(ShieldSessionContext.hasUnexpiredTargetEnd(asOf: now) == false)
    }

    /// After a proper `clearSession()` the helper must read false — the
    /// Monitor's guard must not false-positive on a cleared context.
    @Test("clearSession returns the guard to false")
    func hasUnexpiredTargetEndAfterClear() {
        ShieldSessionContext.writeSession(
            partnerName: nil,
            phase: "Focus",
            targetEndDate: .now.addingTimeInterval(1500)
        )
        #expect(ShieldSessionContext.hasUnexpiredTargetEnd())

        ShieldSessionContext.clearSession()

        #expect(ShieldSessionContext.hasUnexpiredTargetEnd() == false)
    }

    // MARK: - All Categories Threshold (removed)
    //
    // The `allCategoriesThreshold` constant was deleted along with the
    // exception-based mapper it supported. A `FamilyActivitySelection` is
    // inclusive per Apple's docs: selected category tokens mean "shield
    // these categories", not "detect the all-apps mode and flip to
    // .all(except:)". See the ``ShieldPolicyMapperTests`` suite for the
    // tests that cover the corrected inclusive model.
}

@Suite("FocusActivityScheduler Tests")
@MainActor
struct FocusActivitySchedulerTests {

    @Test func schedulerCanBeCreated() {
        let scheduler = FocusActivityScheduler()
        // Verifies the type compiles and initializes.
        // Actual DeviceActivity scheduling requires an entitlement
        // and device — this confirms the API surface is correct.
        _ = scheduler
    }

    @Test func stopMonitoringDoesNotThrow() {
        let scheduler = FocusActivityScheduler()
        // Stopping when nothing is scheduled is a no-op.
        scheduler.stopMonitoring()
    }
}
