import SwiftUI
import WidgetKit

struct FocusStatsTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> FocusStatsEntry {
        FocusStatsEntry(date: .now, snapshot: .preview)
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (FocusStatsEntry) -> Void
    ) {
        let snapshot =
            context.isPreview
            ? WidgetFocusStatsSnapshot.preview
            : WidgetDataReader.readSnapshot()
        completion(FocusStatsEntry(date: .now, snapshot: snapshot))
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<FocusStatsEntry>) -> Void
    ) {
        let snapshot = WidgetDataReader.readSnapshot()
        let entry = FocusStatsEntry(date: .now, snapshot: snapshot)

        let calendar = Calendar.current
        let tomorrow = calendar.startOfDay(
            for: calendar.date(byAdding: .day, value: 1, to: .now) ?? .now
        )
        completion(Timeline(entries: [entry], policy: .after(tomorrow)))
    }
}

struct FocusStatsEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetFocusStatsSnapshot
}

struct FocusStatsWidget: Widget {
    let kind = WidgetKindID.focusStats

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FocusStatsTimelineProvider())
        { entry in
            FocusStatsEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Focus Stats")
        .description("Track today's focus minutes, sessions, and streak.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Entry Router

private struct FocusStatsEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: FocusStatsEntry

    var body: some View {
        switch family {
        case .systemMedium:
            FocusStatsMediumWidget(snapshot: entry.snapshot)
        default:
            FocusStatsSmallWidget(snapshot: entry.snapshot)
        }
    }
}

// MARK: - Small Widget

private struct FocusStatsSmallWidget: View {
    let snapshot: WidgetFocusStatsSnapshot
    private let goalMinutes = 120

    private var progress: Double {
        guard goalMinutes > 0 else { return 0 }
        return min(1, Double(snapshot.todayMinutes) / Double(goalMinutes))
    }

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(
                        WidgetPalette.lavender.opacity(0.18),
                        lineWidth: 6
                    )

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        WidgetPalette.ringGradient,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 1) {
                    Text("\(snapshot.todayMinutes)")
                        .font(.system(.title2, design: .rounded))
                        .bold()
                        .foregroundStyle(WidgetPalette.lavender)
                        .contentTransition(.numericText())

                    Text("min today")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 8)

            if snapshot.currentStreak > 0 {
                Label(
                    "\(snapshot.currentStreak)-day streak",
                    systemImage: "flame.fill"
                )
                .font(.system(.caption2, design: .rounded))
                .bold()
                .foregroundStyle(.orange)
            } else {
                Text("Start a session!")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(WidgetPalette.lavender.opacity(0.7))
            }
        }
    }
}

// MARK: - Medium Widget

private struct FocusStatsMediumWidget: View {
    let snapshot: WidgetFocusStatsSnapshot
    private let goalMinutes = 120

    private var progress: Double {
        guard goalMinutes > 0 else { return 0 }
        return min(1, Double(snapshot.todayMinutes) / Double(goalMinutes))
    }

    var body: some View {
        HStack(spacing: 16) {
            // Progress ring — constrained to prevent overcrowding.
            ProgressRingView(
                minutes: snapshot.todayMinutes,
                progress: progress
            )
            .frame(width: 100, height: 100)

            // Stats column — centered in the remaining space.
            VStack(alignment: .leading, spacing: 10) {
                FocusStatsMetricRow(
                    icon: "brain.head.profile.fill",
                    title: "Sessions",
                    value: "\(snapshot.todaySessionCount)",
                    tint: WidgetPalette.lavender
                )
                FocusStatsMetricRow(
                    icon: "flame.fill",
                    title: "Streak",
                    value: snapshot.currentStreak > 0
                        ? "\(snapshot.currentStreak) days" : "Start one!",
                    tint: .orange
                )
                FocusStatsMetricRow(
                    icon: "target",
                    title: "Goal",
                    value: "\(goalMinutes) min",
                    tint: WidgetPalette.success
                )
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Progress Ring

private struct ProgressRingView: View {
    let minutes: Int
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    WidgetPalette.lavender.opacity(0.18),
                    lineWidth: 7
                )

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    WidgetPalette.ringGradient,
                    style: StrokeStyle(lineWidth: 7, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 1) {
                Text("\(minutes)")
                    .font(.system(.title, design: .rounded))
                    .bold()
                    .foregroundStyle(WidgetPalette.lavender)
                    .contentTransition(.numericText())

                Text("min today")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Metric Row

private struct FocusStatsMetricRow: View {
    let icon: String
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(tint)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.system(.caption, design: .rounded))
                    .bold()
            }
        }
    }
}

// MARK: - Palette

private enum WidgetPalette {
    static let lavender = Color(red: 0.56, green: 0.44, blue: 0.86)
    static let lilac = Color(red: 0.73, green: 0.60, blue: 0.93)
    static let success = Color(red: 0.45, green: 0.73, blue: 0.54)

    /// Subtle angular gradient that gives the ring more depth than a flat color.
    static let ringGradient = AngularGradient(
        colors: [lavender, lilac, lavender],
        center: .center,
        startAngle: .degrees(-90),
        endAngle: .degrees(270)
    )
}

// MARK: - Previews

#Preview("Focus Stats Small", as: .systemSmall) {
    FocusStatsWidget()
} timeline: {
    FocusStatsEntry(date: .now, snapshot: .preview)
    FocusStatsEntry(date: .now, snapshot: .empty())
}

#Preview("Focus Stats Medium", as: .systemMedium) {
    FocusStatsWidget()
} timeline: {
    FocusStatsEntry(date: .now, snapshot: .preview)
    FocusStatsEntry(date: .now, snapshot: .empty())
}
