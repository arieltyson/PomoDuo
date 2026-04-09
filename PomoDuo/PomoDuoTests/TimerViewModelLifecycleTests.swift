import Foundation
import Testing

@testable import PomoDuo

@MainActor
struct TimerViewModelLifecycleTests {

    @Test func stopCancelsTickTask() async {
        let viewModel = TimerViewModel()
        viewModel.startTimer(duration: 60)

        #expect(viewModel.isRunning)

        viewModel.stop()

        #expect(!viewModel.isRunning)
        #expect(viewModel.currentTick == nil)
    }

    @Test func beginNewRunCancelsPreviousTask() async {
        let viewModel = TimerViewModel()
        viewModel.startTimer(duration: 300)
        try? await Task.sleep(for: .milliseconds(50))

        // Starting a new timer should cancel the previous tick task.
        viewModel.startTimer(duration: 60)
        try? await Task.sleep(for: .milliseconds(50))

        #expect(viewModel.isRunning)
        // Only one timer is active — the 60s one.
        if let tick = viewModel.currentTick {
            #expect(tick.totalDuration == 60)
        }
    }
}
