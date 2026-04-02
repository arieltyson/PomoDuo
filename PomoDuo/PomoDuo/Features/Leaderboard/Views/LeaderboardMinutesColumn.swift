import SwiftUI

struct LeaderboardMinutesColumn: View {
    let minutes: Int

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("\(minutes)")
                .font(.body)
                .bold()
                .monospacedDigit()

            Text("min")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 28, alignment: .trailing)
        .accessibilityHidden(true)
    }
}
