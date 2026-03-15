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
                EmptyHistoryView()
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

// MARK: - Empty State

private struct EmptyHistoryView: View {
    var body: some View {
        ContentUnavailableView {
            Label("No Sessions Yet", systemImage: "clock.arrow.circlepath")
        } description: {
            Text("Complete a focus round and it will appear here.")
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
