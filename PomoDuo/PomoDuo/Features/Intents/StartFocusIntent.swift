import AppIntents

/// Opens PomoDuo and requests that a focus session start.
struct StartFocusIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Focus Session"

    static let description = IntentDescription(
        "Open PomoDuo and start a focus session.",
        categoryName: "Focus"
    )

    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        FocusIntentState.shared.requestStartFocus()
        return .result(
            dialog: IntentDialog("Starting a focus session in PomoDuo.")
        )
    }
}
