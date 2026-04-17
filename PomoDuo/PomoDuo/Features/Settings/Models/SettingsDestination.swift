import Foundation

/// Programmatic destinations that can be pushed from the Settings tab.
enum SettingsDestination: Hashable, Sendable {
    case appBlocking
    /// Read-only diagnostics + a destructive reset action for the Screen
    /// Time pipeline. Reachable from the App Blocking screen's toolbar so
    /// users (and on-device diagnosis sessions) can inspect what the app
    /// has configured without leaving the Settings stack.
    case appBlockingDiagnostics
}
