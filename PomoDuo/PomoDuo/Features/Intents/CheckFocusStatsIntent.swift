import AppIntents
import SwiftData

/// Reports today's completed focus stats from SwiftData.
struct CheckFocusStatsIntent: AppIntent {
    static let title: LocalizedStringResource = "Check Focus Stats"

    static let description = IntentDescription(
        "Check how much focus time you completed today.",
        categoryName: "Focus"
    )

    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ReturnsValue<String>
        & ProvidesDialog
    {
        let container = try await MainActor.run {
            try StorageConfiguration.makeContainer()
        }
        let context = ModelContext(container)

        let today = CompletedSession.startOfToday()
        let predicate = #Predicate<CompletedSession> { session in
            session.dayBucket == today
        }

        var descriptor = FetchDescriptor<CompletedSession>(predicate: predicate)
        descriptor.sortBy = [
            SortDescriptor(\CompletedSession.startedAt, order: .reverse)
        ]

        let sessions = try context.fetch(descriptor)
        let totalMinutes = sessions.reduce(0) { partial, session in
            partial + session.focusMinutes
        }
        let summary = Self.summary(
            totalMinutes: totalMinutes,
            sessionCount: sessions.count
        )

        return .result(
            value: summary,
            dialog: IntentDialog(stringLiteral: summary)
        )
    }

    static func summary(totalMinutes: Int, sessionCount: Int) -> String {
        guard sessionCount > 0 else {
            return "You haven't completed any focus sessions today yet."
        }

        let sessionWord = sessionCount == 1 ? "session" : "sessions"
        return
            "You've focused for \(totalMinutes) minutes across \(sessionCount) \(sessionWord) today."
    }
}
