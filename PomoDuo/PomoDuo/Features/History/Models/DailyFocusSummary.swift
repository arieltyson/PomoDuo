import Foundation

/// Aggregated focus metrics for a single day.
struct DailyFocusSummary: Identifiable, Sendable {
    let day: Date
    let totalMinutes: Int
    let sessionCount: Int

    /// Focus minutes from solo sessions.
    let soloMinutes: Int

    /// Focus minutes from paired sessions.
    let pairedMinutes: Int

    var id: Date { day }

    var dayLabel: String {
        day.formatted(.dateTime.weekday(.abbreviated))
    }

    init(
        day: Date,
        totalMinutes: Int,
        sessionCount: Int,
        soloMinutes: Int = 0,
        pairedMinutes: Int = 0
    ) {
        self.day = day
        self.totalMinutes = totalMinutes
        self.sessionCount = sessionCount
        self.soloMinutes = soloMinutes
        self.pairedMinutes = pairedMinutes
    }
}
