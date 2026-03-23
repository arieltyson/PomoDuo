import Foundation

/// A single focus round contributing to a day's chart bar.
struct FocusSegment: Identifiable, Sendable {
    let id: UUID
    let minutes: Int
    let isPaired: Bool

    init(id: UUID = UUID(), minutes: Int, isPaired: Bool) {
        self.id = id
        self.minutes = minutes
        self.isPaired = isPaired
    }
}

/// Aggregated focus metrics for a single day.
struct DailyFocusSummary: Identifiable, Sendable {
    let day: Date
    let totalMinutes: Int
    let sessionCount: Int

    /// Focus minutes from solo sessions.
    let soloMinutes: Int

    /// Focus minutes from paired sessions.
    let pairedMinutes: Int

    /// Individual session segments for chart rendering.
    let segments: [FocusSegment]

    var id: Date { day }

    var dayLabel: String {
        day.formatted(.dateTime.weekday(.abbreviated))
    }

    init(
        day: Date,
        totalMinutes: Int,
        sessionCount: Int,
        soloMinutes: Int = 0,
        pairedMinutes: Int = 0,
        segments: [FocusSegment] = []
    ) {
        self.day = day
        self.totalMinutes = totalMinutes
        self.sessionCount = sessionCount
        self.soloMinutes = soloMinutes
        self.pairedMinutes = pairedMinutes
        self.segments = segments
    }
}
