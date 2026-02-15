//
//  FocusStreakChartView.swift
//  PomoDuo
//
//  Created by Codex on 2/15/26.
//

import Charts
import SwiftUI

/// Weekly bar chart of completed focus minutes.
struct FocusStreakChartView: View {
    let summaries: [DailyFocusSummary]

    var body: some View {
        Chart(summaries) { summary in
            BarMark(
                x: .value("Day", summary.dayLabel),
                y: .value("Minutes", summary.totalMinutes)
            )
            .foregroundStyle(barGradient)
            .annotation(position: .top, spacing: 2) {
                if summary.totalMinutes > 0 {
                    Text("\(summary.totalMinutes)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                    .foregroundStyle(.quaternary)

                AxisValueLabel {
                    if let minutes = value.as(Int.self) {
                        Text("\(minutes)m")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel()
                    .font(.caption)
            }
        }
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var barGradient: LinearGradient {
        LinearGradient(
            colors: [AppColors.lavender, AppColors.lilac],
            startPoint: .bottom,
            endPoint: .top
        )
    }

    private var accessibilitySummary: String {
        let totalMinutes = summaries.reduce(0) { partial, item in
            partial + item.totalMinutes
        }
        let activeDays = summaries.filter { $0.totalMinutes > 0 }.count
        return "Weekly focus chart: \(totalMinutes) minutes across \(activeDays) days"
    }
}
