//
//  WidgetDataProvider.swift
//  PomoDuo
//
//  Created by Codex on 2/15/26.
//

import Foundation
import WidgetKit

/// Writes home widget stats into shared App Group defaults.
enum WidgetDataProvider {
    static let appGroupID = StorageConfiguration.widgetAppGroupID

    private enum Keys {
        static let todayMinutes = "widget.today.minutes"
        static let todaySessionCount = "widget.today.sessionCount"
        static let currentStreak = "widget.today.streak"
        static let lastUpdated = "widget.today.lastUpdated"
        static let dayBucket = "widget.today.dayBucket"
    }

    static func update(
        todayMinutes: Int,
        todaySessionCount: Int,
        currentStreak: Int,
        now: Date = .now,
        calendar: Calendar = .current
    ) {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }

        defaults.set(todayMinutes, forKey: Keys.todayMinutes)
        defaults.set(todaySessionCount, forKey: Keys.todaySessionCount)
        defaults.set(currentStreak, forKey: Keys.currentStreak)
        defaults.set(now.timeIntervalSince1970, forKey: Keys.lastUpdated)
        defaults.set(calendar.startOfDay(for: now).timeIntervalSince1970, forKey: Keys.dayBucket)
    }

    static func reloadWidget() {
        WidgetCenter.shared.reloadTimelines(ofKind: FocusWidgetKind.stats)
    }

    static func readSnapshot(now: Date = .now, calendar: Calendar = .current) -> FocusStatsSnapshot {
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            return .empty(now: now)
        }

        let today = calendar.startOfDay(for: now)
        let storedDay = Date(timeIntervalSince1970: defaults.double(forKey: Keys.dayBucket))

        guard calendar.isDate(storedDay, inSameDayAs: today) else {
            return .empty(now: now)
        }

        return FocusStatsSnapshot(
            todayMinutes: defaults.integer(forKey: Keys.todayMinutes),
            todaySessionCount: defaults.integer(forKey: Keys.todaySessionCount),
            currentStreak: defaults.integer(forKey: Keys.currentStreak),
            lastUpdated: Date(timeIntervalSince1970: defaults.double(forKey: Keys.lastUpdated))
        )
    }
}

struct FocusStatsSnapshot: Sendable {
    let todayMinutes: Int
    let todaySessionCount: Int
    let currentStreak: Int
    let lastUpdated: Date

    static func empty(now: Date = .now) -> FocusStatsSnapshot {
        FocusStatsSnapshot(todayMinutes: 0, todaySessionCount: 0, currentStreak: 0, lastUpdated: now)
    }

    static var preview: FocusStatsSnapshot {
        FocusStatsSnapshot(todayMinutes: 75, todaySessionCount: 3, currentStreak: 5, lastUpdated: .now)
    }
}

enum FocusWidgetKind {
    static let stats = "FocusStatsWidget"
}
