import SwiftUI

struct LeaderboardRankIndicator: View {
    let rank: Int

    var body: some View {
        Text("\(rank)")
            .font(rank <= 3 ? .callout : .caption)
            .bold()
            .monospacedDigit()
            .foregroundStyle(rank <= 3 ? .primary : .secondary)
            .frame(width: 24, alignment: .center)
            .accessibilityHidden(true)
    }
}
