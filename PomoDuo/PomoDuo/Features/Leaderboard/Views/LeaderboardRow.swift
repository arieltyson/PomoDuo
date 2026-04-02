import SwiftUI

struct LeaderboardRow: View {
    let entry: LeaderboardEntry
    let period: LeaderboardPeriod

    var body: some View {
        HStack(spacing: 12) {
            LeaderboardRankIndicator(rank: entry.rank)

            FriendInitialAvatar(name: entry.displayName)

            LeaderboardIdentityColumn(
                displayName: entry.displayName,
                username: entry.username,
                isCurrentUser: entry.isCurrentUser
            )

            Spacer(minLength: 8)

            HStack(spacing: 10) {
                if entry.currentStreak > 0 {
                    LeaderboardStreakBadge(streak: entry.currentStreak)
                }

                LeaderboardMinutesColumn(
                    minutes: entry.focusMinutes(for: period)
                )
            }
            .fixedSize(horizontal: true, vertical: false)
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
