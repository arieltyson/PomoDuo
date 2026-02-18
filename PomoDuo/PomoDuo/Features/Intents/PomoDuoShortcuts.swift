import AppIntents

/// Siri and Shortcuts registration for PomoDuo app intents.
struct PomoDuoShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartFocusIntent(),
            phrases: [
                "Start a focus session in \(.applicationName)",
                "Start focusing in \(.applicationName)",
                "Begin a Pomodoro in \(.applicationName)",
            ],
            shortTitle: "Start Focus",
            systemImageName: "brain.head.profile"
        )

        AppShortcut(
            intent: CheckFocusStatsIntent(),
            phrases: [
                "How much have I focused today in \(.applicationName)",
                "Check my focus stats in \(.applicationName)",
                "Show my focus time in \(.applicationName)",
            ],
            shortTitle: "Check Focus Stats",
            systemImageName: "chart.bar.fill"
        )
    }
}
