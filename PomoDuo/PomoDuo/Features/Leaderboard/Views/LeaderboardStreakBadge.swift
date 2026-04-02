import SwiftUI

struct LeaderboardStreakBadge: View {
    let streak: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .symbolRenderingMode(.hierarchical)

            Text("\(streak)")
                .monospacedDigit()
        }
        .font(.caption)
        .bold()
        .foregroundStyle(AppColors.pauseTint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            AppColors.pauseTint.opacity(0.14),
            in: .capsule
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(streak)-day streak"
        )
    }
}
