import Foundation

/// App Group bridge for communicating Live Activity intent actions
/// between the widget extension and the main app.
///
/// When the user taps Pause / Resume / Stop in the Dynamic Island's
/// expanded view, the ``LiveActivityIntent`` writes a command here.
/// The main app reads and processes it on the next `scenePhase` transition
/// to `.active`.
///
/// > Important: This file must have target membership in **both** the
/// > PomoDuo app and the PomoDuoWidgetExtension.
enum LiveActivityBridge {
    private static let defaults = UserDefaults(
        suiteName: "group.com.arieljtyson.pomoduo"
    )

    private static let commandKey = "liveActivity.command"
    private static let remainingKey = "liveActivity.remainingSeconds"
    private static let timestampKey = "liveActivity.timestamp"

    /// Commands the widget extension can send to the main app.
    enum Command: String {
        case pause
        case resume
        case stop
    }

    /// A pending command written by a Live Activity intent.
    struct PendingCommand: Sendable {
        let command: Command
        let remainingSeconds: TimeInterval
        let timestamp: Date
    }

    // MARK: - Write (Widget Extension)

    /// Writes a command for the main app to process on next foreground.
    static func write(_ command: Command, remainingSeconds: TimeInterval = 0) {
        defaults?.set(command.rawValue, forKey: commandKey)
        defaults?.set(remainingSeconds, forKey: remainingKey)
        defaults?.set(Date.now.timeIntervalSince1970, forKey: timestampKey)
    }

    // MARK: - Read (Main App)

    /// Reads the pending command, if any.
    static func read() -> PendingCommand? {
        guard let rawCommand = defaults?.string(forKey: commandKey),
            let command = Command(rawValue: rawCommand)
        else {
            return nil
        }

        let remaining = defaults?.double(forKey: remainingKey) ?? 0
        let timestamp = Date(
            timeIntervalSince1970: defaults?.double(forKey: timestampKey) ?? 0
        )

        return PendingCommand(
            command: command,
            remainingSeconds: remaining,
            timestamp: timestamp
        )
    }

    /// Clears the pending command after the main app has processed it.
    static func clear() {
        defaults?.removeObject(forKey: commandKey)
        defaults?.removeObject(forKey: remainingKey)
        defaults?.removeObject(forKey: timestampKey)
    }
}
