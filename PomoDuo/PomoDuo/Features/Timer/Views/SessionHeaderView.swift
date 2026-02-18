import SwiftUI

/// Top banner showing session phase and round status.
struct SessionHeaderView: View {
    let phaseName: String
    let currentRound: Int
    let totalRounds: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(phaseName)
                    .font(.title2)
                    .bold()
                    .foregroundStyle(.white)

                Text("Round \(currentRound) of \(totalRounds)")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.88))
            }

            Spacer()

            Image(systemName: phaseIcon)
                .font(.title2)
                .foregroundStyle(.white.opacity(0.82))
                .symbolEffect(
                    .pulse,
                    isActive: !reduceMotion && phaseName == "Focus"
                )
                .accessibilityHidden(true)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(AppGradients.banner)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(phaseName), round \(currentRound) of \(totalRounds)"
        )
        .accessibilityAddTraits(.isHeader)
    }

    private var phaseIcon: String {
        switch phaseName {
        case "Focus":
            "brain.head.profile"
        case "Short Break", "Long Break":
            "cup.and.saucer.fill"
        default:
            "timer"
        }
    }
}
