import DeviceActivity
import Foundation
import OSLog

/// Schedules and cancels DeviceActivity monitoring intervals for focus sessions.
///
/// When a focus session starts, the main app calls ``scheduleMonitoring(until:)``
/// to register an interval with the system. The ``DeviceActivityMonitorExtension``
/// runs independently and receives callbacks when the interval starts and ends,
/// enabling it to reapply or remove shields even if the app is force-quit.
///
/// This is purely on-device — zero Firestore writes.
@MainActor
final class FocusActivityScheduler: Sendable {

    private nonisolated static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.arieljtyson.PomoDuo",
        category: "FocusActivityScheduler"
    )

    private let center = DeviceActivityCenter()

    private static let activityName = DeviceActivityName(
        rawValue: ShieldSessionContext.focusActivityID
    )

    /// Schedules monitoring from now until the given end date.
    ///
    /// The monitor extension receives ``intervalDidStart`` immediately
    /// and ``intervalDidEnd`` when the end date arrives, even if the
    /// app has been force-quit.
    ///
    /// Replaces any previously active schedule.
    func scheduleMonitoring(until endDate: Date) {
        let calendar = Calendar.current

        let startComponents = calendar.dateComponents(
            [.hour, .minute, .second],
            from: .now
        )
        let endComponents = calendar.dateComponents(
            [.hour, .minute, .second],
            from: endDate
        )

        let schedule = DeviceActivitySchedule(
            intervalStart: startComponents,
            intervalEnd: endComponents,
            repeats: false
        )

        do {
            center.stopMonitoring([Self.activityName])
            try center.startMonitoring(Self.activityName, during: schedule)

            Self.logger.info(
                "Focus monitoring scheduled until \(endDate.formatted(.dateTime.hour().minute()), privacy: .public)."
            )
        } catch {
            Self.logger.warning(
                "Failed to schedule focus monitoring: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    /// Cancels any active monitoring interval.
    ///
    /// Call this when the session is paused, enters a break, completes,
    /// or is cleared.
    func stopMonitoring() {
        center.stopMonitoring([Self.activityName])
        Self.logger.info("Focus monitoring stopped.")
    }
}
