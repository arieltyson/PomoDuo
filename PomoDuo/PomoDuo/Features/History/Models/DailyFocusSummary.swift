//
//  DailyFocusSummary.swift
//  PomoDuo
//
//  Created by Codex on 2/15/26.
//

import Foundation

/// Aggregated focus metrics for a single day.
struct DailyFocusSummary: Identifiable, Sendable {
    let day: Date
    let totalMinutes: Int
    let sessionCount: Int

    var id: Date { day }

    var dayLabel: String {
        day.formatted(.dateTime.weekday(.abbreviated))
    }
}
