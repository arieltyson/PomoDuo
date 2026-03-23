import Charts
import SwiftUI

/// Weekly bar chart of completed focus minutes.
///
/// Each session renders as a distinct stacked block within its day's bar,
/// creating a layered visual that conveys session count alongside duration.
/// Solo segments stack at the bottom, paired segments on top.
///
/// When the Differentiate Without Color accessibility setting is on,
/// small person/person.2 icons overlay bar segments so the two series
/// are distinguishable without relying on color.
struct FocusStreakChartView: View {
    let summaries: [DailyFocusSummary]
    var filter: SessionTypeFilter = .all

    @Environment(\.accessibilityDifferentiateWithoutColor)
    private var differentiateWithoutColor
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Chart {
            ForEach(positionedSegments) { segment in
                BarMark(
                    x: .value("Day", segment.dayLabel),
                    yStart: .value("Minutes", segment.yStart),
                    yEnd: .value("Minutes", segment.yEnd),
                    width: .ratio(0.55)
                )
                .cornerRadius(3)
                .foregroundStyle(
                    segment.isPaired ? pairedGradient : soloGradient
                )
                .opacity(segment.index.isMultiple(of: 2) ? 1.0 : 0.82)
                .annotation(position: .overlay) {
                    if differentiateWithoutColor {
                        Image(
                            systemName: segment.isPaired
                                ? "person.2.fill" : "person.fill"
                        )
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))
                    }
                }
                .annotation(position: .top, spacing: 4) {
                    if segment.isLast {
                        Text("\(segment.dayTotal)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityLabel(segmentAccessibilityLabel(segment))
            }
        }
        .chartXScale(domain: summaries.map(\.dayLabel))
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine(
                    stroke: StrokeStyle(lineWidth: 0.5, dash: [4])
                )
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
        .animation(reduceMotion ? .none : .default, value: filter)
    }

    // MARK: - Segment Positioning

    /// Flattens each day's session segments into positioned chart entries
    /// with absolute y-start/end values for stacked rendering.
    private var positionedSegments: [PositionedSegment] {
        var result: [PositionedSegment] = []

        for summary in summaries {
            let ordered: [FocusSegment]

            switch filter {
            case .all:
                let solo = summary.segments.filter { !$0.isPaired }
                let paired = summary.segments.filter { $0.isPaired }
                ordered = solo + paired
            case .solo:
                ordered = summary.segments.filter { !$0.isPaired }
            case .paired:
                ordered = summary.segments.filter { $0.isPaired }
            }

            guard !ordered.isEmpty else { continue }

            let dayTotal = filteredTotal(for: summary)
            var y = 0.0

            for (index, segment) in ordered.enumerated() {
                let start = y
                let end = y + Double(segment.minutes)
                result.append(
                    PositionedSegment(
                        dayLabel: summary.dayLabel,
                        yStart: start,
                        yEnd: end,
                        isPaired: segment.isPaired,
                        index: index,
                        isLast: index == ordered.count - 1,
                        dayTotal: dayTotal
                    )
                )
                y = end
            }
        }

        return result
    }

    private func filteredTotal(for summary: DailyFocusSummary) -> Int {
        switch filter {
        case .all: summary.totalMinutes
        case .solo: summary.soloMinutes
        case .paired: summary.pairedMinutes
        }
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

    private func segmentAccessibilityLabel(
        _ segment: PositionedSegment
    ) -> String {
        let minutes = Int(segment.yEnd - segment.yStart)
        let type = segment.isPaired ? "paired" : "solo"
        return "\(segment.dayLabel): \(minutes) \(type) minutes"
    }

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

// MARK: - Positioned Segment

/// Pre-computed bar segment with absolute y positions for chart rendering.
private struct PositionedSegment: Identifiable {
    let id = UUID()
    let dayLabel: String
    let yStart: Double
    let yEnd: Double
    let isPaired: Bool
    let index: Int
    let isLast: Bool
    let dayTotal: Int
}
