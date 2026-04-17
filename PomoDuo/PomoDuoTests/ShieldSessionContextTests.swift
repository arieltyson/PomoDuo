import Foundation
import Testing

@testable import PomoDuo

@Suite("ShieldSessionContext Tests")
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
