import Foundation
import Testing

@testable import PomoDuo

@MainActor
struct PomodoroTimerRegressionTests {
    @Test func resumingExpiredFocusTimerFinishesAtZero() async {
        await expectExpiredResumeFinishesAtZero(totalDuration: 25 * 60)
    }

    @Test func resumingExpiredBreakTimersFinishAtZero() async {
        await expectExpiredResumeFinishesAtZero(totalDuration: 5 * 60)
        await expectExpiredResumeFinishesAtZero(totalDuration: 15 * 60)
    }

    private func expectExpiredResumeFinishesAtZero(
        totalDuration: TimeInterval
    ) async {
        let timer = PomodoroTimer()
        let stream = await timer.resume(
            targetEndDate: .now.addingTimeInterval(-5),
            totalDuration: totalDuration
        )
        var iterator = stream.makeAsyncIterator()

        guard let firstTick = await iterator.next() else {
            Issue.record("Expected an immediate zero tick for an expired timer.")
            return
        }

        #expect(firstTick.remainingSeconds == 0)
        #expect(firstTick.formattedTime == "00:00")
        #expect(firstTick.progress == 1.0)

        let secondTick = await iterator.next()
        #expect(secondTick == nil)
        #expect(await timer.currentRemaining() == 0)
    }
}
