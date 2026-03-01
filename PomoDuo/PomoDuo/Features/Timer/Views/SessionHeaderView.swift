import SwiftUI

/// Top banner showing session phase and round status.
struct SessionHeaderView: View {
    let phaseName: String
    let currentRound: Int
    let totalRounds: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(phaseName)
                    .font(.title2)
                    .bold()
                    .foregroundStyle(.white)
                    .phaseTransition(phase: phaseName)

                Text("Round \(currentRound) of \(totalRounds)")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.88))
                    .contentTransition(
                        reduceMotion ? .identity : .numericText()
                    )
            }

            Spacer()

            Image(systemName: phaseIcon)
                .font(.title2)
                .foregroundStyle(.white.opacity(0.82))
                .symbolEffect(
                    .pulse,
                    isActive: !reduceMotion && phaseName == "Focus"
                )
                .symbolEffect(
                    .bounce,
                    value: reduceMotion ? "" : phaseName
                )
                .accessibilityHidden(true)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(AppGradients.banner(for: colorScheme))
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
