import Charts
import SwiftUI

/// Weekly bar chart of completed focus minutes.
///
/// With `.all`, bars are stacked by solo and paired contributions.
/// When the Differentiate Without Color accessibility setting is on,
/// small person/person.2 icons overlay bar segments so the two series
/// are distinguishable without relying on color.
struct FocusStreakChartView: View {
    let summaries: [DailyFocusSummary]
    var filter: SessionTypeFilter = .all

    @Environment(\.accessibilityDifferentiateWithoutColor)
    private var differentiateWithoutColor

    var body: some View {
        Chart(summaries) { summary in
            switch filter {
            case .all:
                if summary.soloMinutes > 0 {
                    BarMark(
                        x: .value("Day", summary.dayLabel),
                        yStart: .value("Minutes", 0),
                        yEnd: .value("Minutes", summary.soloMinutes)
                    )
                    .foregroundStyle(soloGradient)
                    .annotation(position: .overlay) {
                        if differentiateWithoutColor {
                            Image(systemName: "person.fill")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundStyle(.white.opacity(0.9))
                        }
                    }
                    .accessibilityLabel(
                        "\(summary.dayLabel): \(summary.soloMinutes) solo minutes"
                    )
                }

                if summary.pairedMinutes > 0 {
                    BarMark(
                        x: .value("Day", summary.dayLabel),
                        yStart: .value("Minutes", summary.soloMinutes),
                        yEnd: .value("Minutes", summary.totalMinutes)
                    )
                    .foregroundStyle(pairedGradient)
                    .annotation(position: .overlay) {
                        if differentiateWithoutColor {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundStyle(.white.opacity(0.9))
                        }
                    }
                    .accessibilityLabel(
                        "\(summary.dayLabel): \(summary.pairedMinutes) paired minutes"
                    )
                }

                if summary.totalMinutes > 0 {
                    BarMark(
                        x: .value("Day", summary.dayLabel),
                        y: .value("Minutes", 0)
                    )
                    .annotation(position: .top, spacing: 2) {
                        Text("\(summary.totalMinutes)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .foregroundStyle(.clear)
                }

            case .solo:
                BarMark(
                    x: .value("Day", summary.dayLabel),
                    y: .value("Minutes", summary.soloMinutes)
                )
                .foregroundStyle(soloGradient)
                .annotation(position: .top, spacing: 2) {
                    if summary.soloMinutes > 0 {
                        Text("\(summary.soloMinutes)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

            case .paired:
                BarMark(
                    x: .value("Day", summary.dayLabel),
                    y: .value("Minutes", summary.pairedMinutes)
                )
                .foregroundStyle(pairedGradient)
                .annotation(position: .top, spacing: 2) {
                    if summary.pairedMinutes > 0 {
                        Text("\(summary.pairedMinutes)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
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
        .animation(.default, value: filter)
    }

    // MARK: - Gradients

    private var soloGradient: LinearGradient {
        LinearGradient(
            colors: [AppColors.lavender, AppColors.lilac],
            startPoint: .bottom,
            endPoint: .top
        )
    }

    private var pairedGradient: LinearGradient {
        LinearGradient(
            colors: [AppColors.lilac, AppColors.paleViolet],
            startPoint: .bottom,
            endPoint: .top
        )
    }

    // MARK: - Accessibility

    private var accessibilitySummary: String {
        switch filter {
        case .all:
            let totalMinutes = summaries.reduce(0) { partial, item in
                partial + item.totalMinutes
            }
            let activeDays = summaries.filter { $0.totalMinutes > 0 }.count
            return
                "Weekly focus chart: \(totalMinutes) minutes across \(activeDays) days"
        case .solo:
            let soloTotal = summaries.reduce(0) { partial, item in
                partial + item.soloMinutes
            }
            let activeDays = summaries.filter { $0.soloMinutes > 0 }.count
            return
                "Weekly solo focus chart: \(soloTotal) minutes across \(activeDays) days"
        case .paired:
            let pairedTotal = summaries.reduce(0) { partial, item in
                partial + item.pairedMinutes
            }
            let activeDays = summaries.filter { $0.pairedMinutes > 0 }.count
            return
                "Weekly paired focus chart: \(pairedTotal) minutes across \(activeDays) days"
        }
    }
}
