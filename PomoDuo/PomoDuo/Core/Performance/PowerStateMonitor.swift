import Foundation
import Observation

/// Tracks Low Power Mode so high-frequency cosmetic work can be throttled.
@MainActor
@Observable
final class PowerStateMonitor {
    private(set) var isLowPowerModeEnabled: Bool

    @ObservationIgnored
    private var observationTask: Task<Void, Never>?

    init() {
        isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
        observationTask = nil
        // Defer creation of the observation task until after self is fully initialized
        let task = Task { @MainActor [weak self] in
            for await _ in NotificationCenter.default.notifications(
                named: .NSProcessInfoPowerStateDidChange
            ) {
                guard let self else { return }
                self.refresh()
            }
        }
        self.observationTask = task
    }

    deinit {
        observationTask?.cancel()
    }

    private func refresh() {
        isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
    }
}
