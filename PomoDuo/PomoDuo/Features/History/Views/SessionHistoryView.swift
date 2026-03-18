import SwiftData
import SwiftUI

/// Displays focus history, weekly charting, and aggregate stats.
///
/// A segmented picker filters the list and chart by session type.
///
/// The query fetches the most recent 200 sessions, which covers roughly
/// two months of heavy daily usage (4 sessions/day). This bounds memory
/// growth while providing sufficient data for weekly charts, streak
/// calculations, and aggregate stats.
struct SessionHistoryView: View {
    @Query private var sessions: [CompletedSession]

    @Environment(AuthManager.self) private var authManager
    @State private var viewModel = SessionHistoryViewModel()

    init() {
        var descriptor = FetchDescriptor<CompletedSession>(
            sortBy: [SortDescriptor(\CompletedSession.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 200
        _sessions = Query(descriptor)
    }

    /// User-scoped sessions before type filtering.
    private var scopedSessions: [CompletedSession] {
        viewModel.scopedSessions(
            from: sessions,
            userID: authManager.currentUserID
        )
    }

    /// Final display list after type filtering.
    private var displaySessions: [CompletedSession] {
        viewModel.filteredSessions(from: scopedSessions)
    }

    var body: some View {
        Group {
            if scopedSessions.isEmpty {
                SkeletonHistoryView()
            } else {
                SessionHistoryListView(
                    displaySessions: displaySessions,
                    viewModel: viewModel
                )
            }
        }
        .navigationTitle("History")
        .task(id: sessions.count) {
            refreshHistory()
        }
        .task(id: authManager.currentUserID) {
            refreshHistory()
        }
    }

    private func refreshHistory() {
        viewModel.refresh(from: sessions, userID: authManager.currentUserID)
    }
}

// MARK: - Skeleton Preview (Empty State)

/// Shows a sample preview of the history layout before the user has any sessions.
///
/// Mirrors the real list structure — stat cards, weekly chart, and session
/// rows — with a redacted shimmer treatment. A disclaimer banner at the top
/// orients the user.
private struct SkeletonHistoryView: View {
    var body: some View {
        List {
            Section {
                SkeletonDisclaimer()
                    .listRowBackground(Color.clear)
                    .listRowInsets(.init(top: 4, leading: 0, bottom: 4, trailing: 0))
            }

            Section {
                HStack {
                    SkeletonStatCard(
                        title: "Total Focus",
                        value: "75",
                        unit: "min",
                        systemImage: "brain.head.profile"
                    )
                    SkeletonStatCard(
                        title: "Sessions",
                        value: "3",
                        unit: "rounds",
                        systemImage: "checkmark.circle"
                    )
                    SkeletonStatCard(
                        title: "Streak",
                        value: "2",
                        unit: "days",
                        systemImage: "flame.fill"
                    )
                }
                .listRowInsets(.init())
                .listRowBackground(Color.clear)
            }

            Section("This Week") {
                SkeletonChartView()
                    .frame(height: 160)
                    .listRowInsets(
                        .init(top: 8, leading: 16, bottom: 8, trailing: 16)
                    )
            }

            Section("Recent Sessions") {
                ForEach(SkeletonSession.samples) { sample in
                    SkeletonSessionRow(sample: sample)
                }
            }
        }
        .redacted(reason: .placeholder)
        .allowsHitTesting(false)
        .accessibilityLabel(
            "Sample history preview. Complete a focus round to see your real data here."
        )
    }
}

// MARK: - Skeleton Disclaimer

/// Banner explaining the skeleton is sample data.
private struct SkeletonDisclaimer: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.body.weight(.semibold))
                .foregroundStyle(AppColors.lavender)
                .unredacted()

            VStack(alignment: .leading, spacing: 2) {
                Text("This is a preview")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .unredacted()

                Text("Complete your first focus round and your real stats will appear here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .unredacted()
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.lavender.opacity(0.08), in: .rect(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Skeleton Stat Card

private struct SkeletonStatCard: View {
    let title: String
    let value: String
    let unit: String
    let systemImage: String

    var body: some View {
        VStack {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(AppColors.lavender)

            Text(value)
                .font(.title2)
                .bold()
                .monospacedDigit()

            Text(unit)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical)
        .background(AppColors.paleViolet.opacity(0.15))
        .clipShape(.rect(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value) \(unit)")
    }
}

// MARK: - Skeleton Chart

/// Placeholder bar chart using simple rounded rectangles.
private struct SkeletonChartView: View {
    private static let barHeights: [CGFloat] = [0.4, 0.65, 0.3, 0.85, 0.55, 0.7, 0.2]

    private static var dayLabels: [String] {
        let calendar = Calendar.current
        return (0..<7).reversed().map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: .now) ?? .now
            return day.formatted(.dateTime.weekday(.abbreviated))
        }
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            ForEach(Array(zip(Self.dayLabels, Self.barHeights)), id: \.0) { label, height in
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppColors.lavender.opacity(0.35).gradient)
                        .frame(height: 100 * height)

                    Text(label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Skeleton Session Row

/// Static data driving the sample session rows.
private struct SkeletonSession: Identifiable {
    let id: Int
    let minutes: Int
    let round: Int
    let totalRounds: Int
    let isPaired: Bool
    let hoursAgo: Int

    static let samples: [SkeletonSession] = [
        SkeletonSession(id: 0, minutes: 25, round: 1, totalRounds: 4, isPaired: false, hoursAgo: 2),
        SkeletonSession(id: 1, minutes: 25, round: 2, totalRounds: 4, isPaired: false, hoursAgo: 3),
        SkeletonSession(id: 2, minutes: 25, round: 1, totalRounds: 4, isPaired: true, hoursAgo: 26),
    ]
}

private struct SkeletonSessionRow: View {
    let sample: SkeletonSession

    var body: some View {
        HStack {
            Image(systemName: sample.isPaired ? "person.2.fill" : "person.fill")
                .foregroundStyle(sample.isPaired ? AppColors.lilac : AppColors.lavender)
                .frame(width: 32, height: 32)
                .background(AppColors.paleViolet.opacity(0.2))
                .clipShape(.circle)

            VStack(alignment: .leading) {
                Text("\(sample.minutes) min focus")
                    .font(.subheadline)
                    .bold()

                Text("Round \(sample.round) of \(sample.totalRounds)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing) {
                Text("12:00 PM")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Mar 18")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

// MARK: - List

private struct SessionHistoryListView: View {
    let displaySessions: [CompletedSession]
    @Bindable var viewModel: SessionHistoryViewModel

    var body: some View {
        List {
            StatsSection(viewModel: viewModel)

            Section("This Week") {
                FocusStreakChartView(
                    summaries: viewModel.weeklySummaries,
                    filter: viewModel.activeFilter
                )
                .frame(height: 160)
                .listRowInsets(
                    .init(top: 8, leading: 0, bottom: 8, trailing: 0)
                )
            }

            Section {
                SessionFilterPicker(selection: $viewModel.activeFilter)
                    .listRowInsets(.init())
                    .listRowBackground(Color.clear)
            }

            if displaySessions.isEmpty {
                Section {
                    FilteredEmptyStateView(filter: viewModel.activeFilter)
                }
            } else {
                Section("Recent Sessions") {
                    ForEach(displaySessions.prefix(50)) { session in
                        SessionRowView(session: session)
                    }
                }
            }
        }
    }
}

// MARK: - Stats

private struct StatsSection: View {
    let viewModel: SessionHistoryViewModel

    var body: some View {
        Section {
            HStack {
                StatCard(
                    title: "Total Focus",
                    value: "\(viewModel.allTimeFocusMinutes)",
                    unit: "min",
                    systemImage: "brain.head.profile"
                )

                StatCard(
                    title: "Sessions",
                    value: "\(viewModel.allTimeSessionCount)",
                    unit: "rounds",
                    systemImage: "checkmark.circle"
                )

                StatCard(
                    title: "Streak",
                    value: "\(viewModel.currentStreak)",
                    unit: viewModel.currentStreak == 1 ? "day" : "days",
                    systemImage: "flame.fill"
                )
            }
            .listRowInsets(.init())
            .listRowBackground(Color.clear)

            if viewModel.pairedSessionCount > 0 {
                PairedStatsRow(viewModel: viewModel)
            }
        }
    }
}

/// Solo/paired contribution row beneath primary stats cards.
private struct PairedStatsRow: View {
    let viewModel: SessionHistoryViewModel

    var body: some View {
        HStack {
            Label {
                Text("\(viewModel.soloFocusMinutes) min solo")
                    .font(.caption)
            } icon: {
                Image(systemName: "person.fill")
                    .foregroundStyle(AppColors.lavender)
            }

            Spacer()

            Label {
                Text("\(viewModel.pairedFocusMinutes) min paired")
                    .font(.caption)
            } icon: {
                Image(systemName: "person.2.fill")
                    .foregroundStyle(AppColors.lilac)
            }
        }
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(viewModel.soloFocusMinutes) minutes solo, \(viewModel.pairedFocusMinutes) minutes paired"
        )
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    let unit: String
    let systemImage: String

    var body: some View {
        VStack {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(AppColors.lavender)

            Text(value)
                .font(.title2)
                .bold()
                .monospacedDigit()

            Text(unit)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical)
        .background(AppColors.paleViolet.opacity(0.15))
        .clipShape(.rect(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value) \(unit)")
    }
}

// MARK: - Filter Picker

private struct SessionFilterPicker: View {
    @Binding var selection: SessionTypeFilter

    var body: some View {
        Picker("Session Type", selection: $selection) {
            ForEach(SessionTypeFilter.allCases) { filter in
                Text(filter.title)
                    .tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .accessibilityHint("Filters history by all, solo, or paired sessions.")
    }
}

// MARK: - Filtered Empty State

private struct FilteredEmptyStateView: View {
    let filter: SessionTypeFilter

    var body: some View {
        ContentUnavailableView {
            Label(emptyTitle, systemImage: emptySymbol)
        } description: {
            Text(emptyDescription)
        }
    }

    private var emptyTitle: String {
        switch filter {
        case .all:
            "No Sessions"
        case .solo:
            "No Solo Sessions"
        case .paired:
            "No Paired Sessions"
        }
    }

    private var emptySymbol: String {
        switch filter {
        case .all:
            "clock.arrow.circlepath"
        case .solo:
            "person.fill"
        case .paired:
            "person.2.fill"
        }
    }

    private var emptyDescription: String {
        switch filter {
        case .all:
            "Complete a focus round and it will appear here."
        case .solo:
            "Start a solo focus session from the Focus tab."
        case .paired:
            "Start a paired session with your study partner."
        }
    }
}
