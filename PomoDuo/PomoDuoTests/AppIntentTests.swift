import Foundation
import Testing

@testable import PomoDuo

@MainActor
struct FocusIntentStateTests {
    @Test func sharedIsSingleton() {
        let first = FocusIntentState.shared
        let second = FocusIntentState.shared

        #expect(first === second)
    }

    @Test func requestAndConsumeLifecycle() {
        let state = FocusIntentState.shared

        _ = state.consumeStartFocusRequest()
        #expect(state.pendingFocusRequest == false)

        state.requestStartFocus()
        #expect(state.pendingFocusRequest)

        let consumed = state.consumeStartFocusRequest()
        #expect(consumed)
        #expect(state.pendingFocusRequest == false)
    }
}

@MainActor
struct StartFocusIntentTests {
    @Test func opensAppWhenRun() {
        #expect(StartFocusIntent.openAppWhenRun)
    }

    @Test func performSetsPendingRequest() async throws {
        let state = FocusIntentState.shared
        _ = state.consumeStartFocusRequest()

        let intent = StartFocusIntent()
        _ = try await intent.perform()

        #expect(state.pendingFocusRequest)

        _ = state.consumeStartFocusRequest()
    }
}

@MainActor
struct CheckFocusStatsIntentTests {
    @Test func doesNotOpenAppWhenRun() {
        #expect(CheckFocusStatsIntent.openAppWhenRun == false)
    }

    @Test func zeroSessionSummary() {
        let summary = CheckFocusStatsIntent.summary(
            totalMinutes: 0,
            sessionCount: 0
        )
        #expect(summary.localizedStandardContains("haven't completed"))
    }

    @Test func singularSummary() {
        let summary = CheckFocusStatsIntent.summary(
            totalMinutes: 25,
            sessionCount: 1
        )
        #expect(summary.localizedStandardContains("25"))
        #expect(summary.localizedStandardContains("1 session"))
    }

    @Test func pluralSummary() {
        let summary = CheckFocusStatsIntent.summary(
            totalMinutes: 75,
            sessionCount: 3
        )
        #expect(summary.localizedStandardContains("75"))
        #expect(summary.localizedStandardContains("3 sessions"))
    }
}

@MainActor
struct PomoDuoShortcutsTests {
    @Test func registersTwoShortcuts() {
        #expect(PomoDuoShortcuts.appShortcuts.count == 2)
    }
}
