import Foundation
import Testing

@testable import PomoDuo

/// Regression tests for the progress ring clamping logic that eliminates
/// the residual arc artifact when focus or break timers reach 00:00.
struct CircularProgressClampTests {

    // MARK: - Zero / Near-Zero (the bug fix)

    @Test("Focus timer at exactly zero shows no ring")
    func exactlyZeroSnapsToZero() {
        #expect(clampedRingProgress(0.0) == 0)
    }

    @Test("Break timer near-zero residual is eliminated")
    func nearZeroResidualSnapsToZero() {
        // Floating-point drift can leave ~0.001–0.004 remaining.
        #expect(clampedRingProgress(0.001) == 0)
        #expect(clampedRingProgress(0.004) == 0)
        #expect(clampedRingProgress(0.0049) == 0)
    }

    @Test("Threshold boundary: 0.005 is preserved")
    func thresholdBoundaryPreserved() {
        #expect(clampedRingProgress(0.005) == 0.005)
    }

    // MARK: - Negative Values

    @Test("Negative progress clamps to zero")
    func negativeProgressClampsToZero() {
        #expect(clampedRingProgress(-0.1) == 0)
        #expect(clampedRingProgress(-1.0) == 0)
    }

    // MARK: - Normal Range

    @Test("Mid-range values pass through unchanged")
    func midRangePassesThrough() {
        #expect(clampedRingProgress(0.5) == 0.5)
        #expect(clampedRingProgress(0.25) == 0.25)
        #expect(clampedRingProgress(0.99) == 0.99)
    }

    @Test("Full progress is preserved")
    func fullProgressPreserved() {
        #expect(clampedRingProgress(1.0) == 1.0)
    }

    // MARK: - Overflow

    @Test("Progress above 1.0 clamps to 1.0")
    func overflowClampsToOne() {
        #expect(clampedRingProgress(1.1) == 1.0)
        #expect(clampedRingProgress(2.0) == 1.0)
    }

    // MARK: - Realistic Timer Scenarios

    @Test("Focus session last-second progress values")
    func focusSessionLastSecondProgress() {
        // 1 second remaining out of 25 min = 1/1500 ≈ 0.000667
        let oneSecondOfTwentyFiveMin = 1.0 / (25.0 * 60.0)
        #expect(clampedRingProgress(oneSecondOfTwentyFiveMin) == 0)
    }

    @Test("Break session last-second progress values")
    func breakSessionLastSecondProgress() {
        // 1 second remaining out of 5 min = 1/300 ≈ 0.00333
        let oneSecondOfFiveMin = 1.0 / (5.0 * 60.0)
        #expect(clampedRingProgress(oneSecondOfFiveMin) == 0)
    }

    @Test("Long break last-second still within threshold")
    func longBreakLastSecondProgress() {
        // 1 second remaining out of 15 min = 1/900 ≈ 0.00111
        let oneSecondOfFifteenMin = 1.0 / (15.0 * 60.0)
        #expect(clampedRingProgress(oneSecondOfFifteenMin) == 0)
    }

    @Test("Two seconds of five-min break stays visible")
    func twoSecondsOfBreakStaysVisible() {
        // 2 seconds remaining out of 5 min = 2/300 ≈ 0.00667
        let twoSecondsOfFiveMin = 2.0 / (5.0 * 60.0)
        #expect(clampedRingProgress(twoSecondsOfFiveMin) > 0)
    }
}
