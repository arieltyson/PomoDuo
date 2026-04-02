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

    private var maxMinutes: Int {
        entries.map { $0.focusMinutes(for: period) }.max() ?? 1
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if entries.count >= 2 {
                PodiumColumn(
                    entry: entries[1],
                    period: period,
                    maxHeight: 90,
                    fraction: barFraction(for: entries[1])
                )
            }

            if entries.count >= 1 {
                PodiumColumn(
                    entry: entries[0],
                    period: period,
                    maxHeight: 120,
                    fraction: barFraction(for: entries[0])
                )
            }

            if entries.count >= 3 {
                PodiumColumn(
                    entry: entries[2],
                    period: period,
                    maxHeight: 70,
                    fraction: barFraction(for: entries[2])
                )
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Top \(entries.count) leaderboard")
    }

    private func barFraction(for entry: LeaderboardEntry) -> Double {
        guard maxMinutes > 0 else { return 0 }
        return Double(entry.focusMinutes(for: period)) / Double(maxMinutes)
    }
}

private struct PodiumColumn: View {
    let entry: LeaderboardEntry
    let period: LeaderboardPeriod
    let maxHeight: CGFloat
    let fraction: Double

    /// Minimum bar height so the column remains visible even at 0 minutes.
    private static let minBarHeight: CGFloat = 8

    private var barHeight: CGFloat {
        let scaled = maxHeight * fraction
        return max(scaled, Self.minBarHeight)
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(rankMedal)
                .font(.title2)

            Text(entry.displayName.components(separatedBy: " ").first ?? entry.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)

            VStack(spacing: 2) {
                Text("\(entry.focusMinutes(for: period))")
                    .font(.title3)
                    .bold()
                    .monospacedDigit()

                Text("min")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            RoundedRectangle(cornerRadius: 12)
                .fill(podiumGradient.opacity(fraction > 0 ? 1 : 0.3))
                .frame(maxWidth: .infinity)
                .frame(height: barHeight)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(ordinalRank) place, \(entry.displayName), \(entry.focusMinutes(for: period)) minutes"
        )
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
