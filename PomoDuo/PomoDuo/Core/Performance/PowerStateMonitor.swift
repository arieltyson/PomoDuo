import Foundation
import Observation

/// Tracks Low Power Mode so high-frequency cosmetic work can be throttled.
@MainActor
@Observable
final class PowerStateMonitor {
    private(set) var isLowPowerModeEnabled: Bool

    private var observationTask: Task<Void, Never>?

    init() {
        isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
        observationTask = Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(
                named: .NSProcessInfoPowerStateDidChange
            ) {
                guard let self else { return }
                await self.refresh()
            }
        }
    }

    deinit {
        observationTask?.cancel()
    }

    private func refresh() {
        isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
    }
}
