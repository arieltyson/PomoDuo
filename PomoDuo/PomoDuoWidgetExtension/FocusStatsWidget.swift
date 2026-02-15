//
//  FocusStatsWidget.swift
//  PomoDuoWidgetExtension
//
//  Created by Codex on 2/15/26.
//

import SwiftUI
import WidgetKit

struct FocusStatsTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> FocusStatsEntry {
        FocusStatsEntry(date: .now, snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (FocusStatsEntry) -> Void) {
        let snapshot = context.isPreview
            ? WidgetFocusStatsSnapshot.preview
            : WidgetDataReader.readSnapshot()
        completion(FocusStatsEntry(date: .now, snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FocusStatsEntry>) -> Void) {
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
        StaticConfiguration(kind: kind, provider: FocusStatsTimelineProvider()) { entry in
            FocusStatsEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Focus Stats")
        .description("Track today’s focus minutes, sessions, and streak.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

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

private struct FocusStatsSmallWidget: View {
    let snapshot: WidgetFocusStatsSnapshot
    private let goalMinutes = 120

    private var progress: Double {
        guard goalMinutes > 0 else { return 0 }
        return min(1, Double(snapshot.todayMinutes) / Double(goalMinutes))
    }

    var body: some View {
        VStack {
            ZStack {
                Circle()
                    .stroke(WidgetPalette.lavender.opacity(0.24), lineWidth: 7)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(WidgetPalette.lavender, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("\(snapshot.todayMinutes)")
                        .font(.system(.title2, design: .rounded))
                        .bold()
                        .foregroundStyle(WidgetPalette.lavender)

                    Text("min")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if snapshot.currentStreak > 0 {
                Label("\(snapshot.currentStreak) day streak", systemImage: "flame.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .padding(6)
    }
}

private struct FocusStatsMediumWidget: View {
    let snapshot: WidgetFocusStatsSnapshot
    private let goalMinutes = 120

    private var progress: Double {
        guard goalMinutes > 0 else { return 0 }
        return min(1, Double(snapshot.todayMinutes) / Double(goalMinutes))
    }

    var body: some View {
        HStack {
            ZStack {
                Circle()
                    .stroke(WidgetPalette.lavender.opacity(0.24), lineWidth: 8)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(WidgetPalette.lavender, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("\(snapshot.todayMinutes)")
                        .font(.system(.title, design: .rounded))
                        .bold()
                        .foregroundStyle(WidgetPalette.lavender)

                    Text("min today")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxHeight: .infinity)
            .aspectRatio(1, contentMode: .fit)

            VStack(alignment: .leading) {
                FocusStatsMetricRow(icon: "brain.head.profile.fill", title: "Sessions", value: "\(snapshot.todaySessionCount)", tint: WidgetPalette.lavender)
                FocusStatsMetricRow(icon: "flame.fill", title: "Streak", value: snapshot.currentStreak > 0 ? "\(snapshot.currentStreak) days" : "Start one!", tint: .orange)
                FocusStatsMetricRow(icon: "target", title: "Goal", value: "\(goalMinutes) min", tint: WidgetPalette.success)
            }
        }
        .padding(4)
    }
}

private struct FocusStatsMetricRow: View {
    let icon: String
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(tint)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.caption)
                    .bold()
            }
        }
    }
}

private enum WidgetPalette {
    static let lavender = Color(red: 0.56, green: 0.44, blue: 0.86)
    static let success = Color(red: 0.45, green: 0.73, blue: 0.54)
}

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
