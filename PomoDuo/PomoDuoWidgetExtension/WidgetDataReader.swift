import Foundation

enum WidgetDataReader {
    private static let appGroupID = "group.com.arieljtyson.pomoduo"

    private enum Keys {
        static let todayMinutes = "widget.today.minutes"
        static let todaySessionCount = "widget.today.sessionCount"
        static let currentStreak = "widget.today.streak"
        static let lastUpdated = "widget.today.lastUpdated"
        static let dayBucket = "widget.today.dayBucket"
    }

    static func readSnapshot(now: Date = .now, calendar: Calendar = .current)
        -> WidgetFocusStatsSnapshot
    {
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            return .empty(now: now)
        }

        let today = calendar.startOfDay(for: now)
        let storedDay = Date(
            timeIntervalSince1970: defaults.double(forKey: Keys.dayBucket)
        )

        guard calendar.isDate(storedDay, inSameDayAs: today) else {
            return .empty(now: now)
        }

        return WidgetFocusStatsSnapshot(
            todayMinutes: defaults.integer(forKey: Keys.todayMinutes),
            todaySessionCount: defaults.integer(forKey: Keys.todaySessionCount),
            currentStreak: defaults.integer(forKey: Keys.currentStreak),
            lastUpdated: Date(
                timeIntervalSince1970: defaults.double(forKey: Keys.lastUpdated)
            )
        )
    }
}

struct WidgetFocusStatsSnapshot: Sendable {
    let todayMinutes: Int
    let todaySessionCount: Int
    let currentStreak: Int
    let lastUpdated: Date

    static func empty(now: Date = .now) -> WidgetFocusStatsSnapshot {
        WidgetFocusStatsSnapshot(
            todayMinutes: 0,
            todaySessionCount: 0,
            currentStreak: 0,
            lastUpdated: now
        )
    }

    static var preview: WidgetFocusStatsSnapshot {
        WidgetFocusStatsSnapshot(
            todayMinutes: 75,
            todaySessionCount: 3,
            currentStreak: 5,
            lastUpdated: .now
        )
    }
}

enum WidgetKindID {
    static let focusStats = "FocusStatsWidget"
}
