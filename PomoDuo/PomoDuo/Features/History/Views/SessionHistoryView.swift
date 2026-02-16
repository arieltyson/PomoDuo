//
//  SessionHistoryView.swift
//  PomoDuo
//
//  Created by Codex on 2/15/26.
//

import SwiftData
import SwiftUI

/// Displays focus history, weekly charting, and aggregate stats.
struct SessionHistoryView: View {
    @Query(sort: \CompletedSession.startedAt, order: .reverse)
    private var sessions: [CompletedSession]

    @Environment(AuthManager.self) private var authManager
    @State private var viewModel = SessionHistoryViewModel()

    private var filteredSessions: [CompletedSession] {
        viewModel.scopedSessions(from: sessions, userID: authManager.currentUserID)
    }

    var body: some View {
        Group {
            if filteredSessions.isEmpty {
                EmptyHistoryView()
            } else {
                SessionHistoryListView(sessions: filteredSessions, viewModel: viewModel)
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

private struct EmptyHistoryView: View {
    var body: some View {
        ContentUnavailableView {
            Label("No Sessions Yet", systemImage: "clock.arrow.circlepath")
        } description: {
            Text("Complete a focus round and it will appear here.")
        }
    }
}

private struct SessionHistoryListView: View {
    let sessions: [CompletedSession]
    let viewModel: SessionHistoryViewModel

    var body: some View {
        List {
            StatsSection(viewModel: viewModel)

            Section("This Week") {
                FocusStreakChartView(summaries: viewModel.weeklySummaries)
                    .frame(height: 160)
                    .listRowInsets(.init(top: 8, leading: 0, bottom: 8, trailing: 0))
            }

            Section("Recent Sessions") {
                ForEach(sessions.prefix(50)) { session in
                    SessionRowView(session: session)
                }
            }
        }
    }
}

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
        }
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
