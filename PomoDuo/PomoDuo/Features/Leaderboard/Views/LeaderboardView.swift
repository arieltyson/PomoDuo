import SwiftUI

/// Friends leaderboard showing ranked focus stats.
struct LeaderboardView: View {
    @State private var viewModel: LeaderboardViewModel

    init(friendService: any FriendService) {
        _viewModel = State(
            initialValue: LeaderboardViewModel(friendService: friendService)
        )
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.entries.isEmpty {
                ProgressView("Loading leaderboard…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.entries.isEmpty {
                LeaderboardEmptyView()
            } else {
                LeaderboardListView(viewModel: viewModel)
            }
        }
        .navigationTitle("Leaderboard")
        .task {
            await viewModel.refresh()
        }
        .task(id: viewModel.period) {
            await viewModel.refresh()
        }
        .refreshable {
            await viewModel.refresh()
        }
        .alert(
            "Error",
            isPresented: Binding(
                get: { viewModel.error != nil },
                set: { if !$0 { viewModel.dismissError() } }
            )
        ) {
            Button("OK") { viewModel.dismissError() }
        } message: {
            if let error = viewModel.error {
                Text(error)
            }
        }
    }
}

// MARK: - List

private struct LeaderboardListView: View {
    @Bindable var viewModel: LeaderboardViewModel

    var body: some View {
        List {
            Section {
                Picker("Period", selection: $viewModel.period) {
                    ForEach(LeaderboardPeriod.allCases) { period in
                        Text(period.title)
                            .tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .listRowInsets(.init())
                .listRowBackground(Color.clear)
            }

            if let podium = podiumEntries, !podium.isEmpty {
                Section {
                    PodiumView(
                        entries: podium,
                        period: viewModel.period
                    )
                    .listRowInsets(.init())
                    .listRowBackground(Color.clear)
                }
            }

            Section {
                ForEach(viewModel.entries) { entry in
                    LeaderboardRow(
                        entry: entry,
                        period: viewModel.period
                    )
                }
            } header: {
                Text("Rankings")
            }
        }
        .scrollIndicators(.hidden)
    }

    private var podiumEntries: [LeaderboardEntry]? {
        let top = Array(viewModel.entries.prefix(3))
        guard top.count >= 2 else { return nil }
        return top
    }
}

// MARK: - Podium

private struct PodiumView: View {
    let entries: [LeaderboardEntry]
    let period: LeaderboardPeriod

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if entries.count >= 2 {
                PodiumColumn(entry: entries[1], period: period, height: 90)
            }

            if entries.count >= 1 {
                PodiumColumn(entry: entries[0], period: period, height: 120)
            }

            if entries.count >= 3 {
                PodiumColumn(entry: entries[2], period: period, height: 70)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Top \(entries.count) leaderboard")
    }
}

private struct PodiumColumn: View {
    let entry: LeaderboardEntry
    let period: LeaderboardPeriod
    let height: CGFloat

    var body: some View {
        VStack(spacing: 6) {
            Text(rankMedal)
                .font(.title2)

            Text(entry.displayName.components(separatedBy: " ").first ?? entry.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)

            VStack(spacing: 2) {
                Text("\(focusMinutes)")
                    .font(.title3)
                    .bold()
                    .monospacedDigit()

                Text("min")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(podiumGradient, in: .rect(cornerRadii: .init(topLeading: 12, topTrailing: 12)))
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(ordinalRank) place, \(entry.displayName), \(focusMinutes) minutes"
        )
    }

    private var focusMinutes: Int {
        switch period {
        case .today:
            entry.dailyFocusMinutes
        case .thisWeek:
            entry.weeklyFocusMinutes
        case .allTime:
            entry.totalFocusMinutes
        }
    }

    private var rankMedal: String {
        switch entry.rank {
        case 1: "🥇"
        case 2: "🥈"
        case 3: "🥉"
        default: "\(entry.rank)"
        }
    }

    private var ordinalRank: String {
        switch entry.rank {
        case 1: "1st"
        case 2: "2nd"
        case 3: "3rd"
        default: "\(entry.rank)th"
        }
    }

    private var podiumGradient: some ShapeStyle {
        switch entry.rank {
        case 1:
            AppColors.lavender.gradient
        case 2:
            AppColors.lilac.gradient
        default:
            AppColors.paleViolet.gradient
        }
    }
}

// MARK: - Row

private struct LeaderboardRow: View {
    let entry: LeaderboardEntry
    let period: LeaderboardPeriod

    var body: some View {
        HStack(spacing: 12) {
            RankBadge(rank: entry.rank)

            FriendInitialAvatar(name: entry.displayName)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(entry.displayName)
                        .font(.body)
                        .fontWeight(entry.isCurrentUser ? .bold : .medium)

                    if entry.isCurrentUser {
                        Text("You")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(AppColors.lavender)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                AppColors.paleViolet.opacity(0.3),
                                in: .capsule
                            )
                    }
                }

                if !entry.username.isEmpty {
                    Text("@\(entry.username)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(focusMinutes)")
                    .font(.body)
                    .bold()
                    .monospacedDigit()

                Text("min")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if entry.currentStreak > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)

                    Text("\(entry.currentStreak)")
                        .font(.caption)
                        .bold()
                        .monospacedDigit()
                }
            }
        }
        .listRowBackground(
            entry.isCurrentUser
                ? AppColors.paleViolet.opacity(0.12)
                : nil
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(entry.rank). \(entry.displayName), \(focusMinutes) minutes, \(entry.currentStreak) day streak"
        )
    }

    private var focusMinutes: Int {
        switch period {
        case .today:
            entry.dailyFocusMinutes
        case .thisWeek:
            entry.weeklyFocusMinutes
        case .allTime:
            entry.totalFocusMinutes
        }
    }
}

// MARK: - Rank Badge

private struct RankBadge: View {
    let rank: Int

    var body: some View {
        Text("\(rank)")
            .font(.caption)
            .bold()
            .monospacedDigit()
            .foregroundStyle(rank <= 3 ? .white : .secondary)
            .frame(width: 28, height: 28)
            .background(badgeColor, in: .circle)
    }

    private var badgeColor: Color {
        switch rank {
        case 1: AppColors.lavender
        case 2: AppColors.lilac
        case 3: AppColors.paleViolet
        default: .clear
        }
    }
}

// MARK: - Empty State

private struct LeaderboardEmptyView: View {
    var body: some View {
        ContentUnavailableView {
            Label("No Leaderboard Data", systemImage: "trophy")
        } description: {
            Text(
                "Add friends and complete focus sessions to see the leaderboard."
            )
        }
    }
}
