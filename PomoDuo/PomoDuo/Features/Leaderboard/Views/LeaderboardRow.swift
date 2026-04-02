import SwiftUI

struct LeaderboardRow: View {
    private enum Layout {
        static let trailingMetricsWidth: CGFloat = 112
    }

    let entry: LeaderboardEntry
    let period: LeaderboardPeriod

    var body: some View {
        HStack(spacing: 12) {
            LeaderboardRankIndicator(rank: entry.rank)

            FriendInitialAvatar(name: entry.displayName)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if entry.isCurrentUser {
                        Text(entry.displayName)
                            .font(.body)
                            .bold()
                            .lineLimit(1)
                    } else {
                        Text(entry.displayName)
                            .font(.body)
                            .lineLimit(1)
                    }

                    if entry.isCurrentUser {
                        Text("You")
                            .font(.caption2)
                            .bold()
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
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 12)

            HStack(spacing: 10) {
                if entry.currentStreak > 0 {
                    LeaderboardStreakBadge(streak: entry.currentStreak)
                }

                LeaderboardMinutesColumn(
                    minutes: entry.focusMinutes(for: period)
                )
            }
            .frame(minWidth: Layout.trailingMetricsWidth, alignment: .trailing)
        }
        .listRowBackground(
            entry.isCurrentUser
                ? AppColors.paleViolet.opacity(0.12)
                : nil
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        if entry.currentStreak > 0 {
            "\(entry.rank). \(entry.displayName), \(entry.focusMinutes(for: period)) minutes, \(streakSummary)"
        } else {
            "\(entry.rank). \(entry.displayName), \(entry.focusMinutes(for: period)) minutes"
        }
    }

    private var streakSummary: String {
        "\(entry.currentStreak)-day streak"
    }
}
