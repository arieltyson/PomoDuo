import SwiftUI

/// Dot indicator for completed/current/upcoming focus rounds.
struct RoundIndicatorView: View {
    let currentRound: Int
    let totalRounds: Int

    var body: some View {
        HStack {
            ForEach(1...totalRounds, id: \.self) { round in
                RoundDot(state: dotState(for: round))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Round \(currentRound) of \(totalRounds)")
    }

    private func dotState(for round: Int) -> RoundDotState {
        if round < currentRound {
            .completed
        } else if round == currentRound {
            .current
        } else {
            .upcoming
        }
    }
}

private enum RoundDotState {
    case completed
    case current
    case upcoming
}

private struct RoundDot: View {
    let state: RoundDotState

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle()
                .fill(dotColor)
                .frame(
                    width: state == .current ? 10 : 8,
                    height: state == .current ? 10 : 8
                )
                .scaleEffect(state == .current ? 1.2 : 1)
                .animation(
                    reduceMotion ? .none : .bouncy(duration: 0.35),
                    value: state == .current
                )

            // Checkmark overlay for completed rounds.
            if state == .completed {
                Image(systemName: "checkmark")
                    .font(.system(size: 5, weight: .bold))
                    .foregroundStyle(.white)
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .scale.combined(with: .opacity)
                    )
            }

            // Pulse ring for current round.
            if state == .current {
                CurrentRoundPulse()
            }
        }
        .roundCompletionPop(isCompleted: state == .completed)
        .animation(
            reduceMotion ? .none : .spring(duration: 0.4, bounce: 0.3),
            value: state == .current
        )
    }

    private var dotColor: Color {
        switch state {
        case .completed:
            AppColors.lavender
        case .current:
            AppColors.lilac
        case .upcoming:
            AppColors.paleViolet.opacity(0.45)
        }
    }
}

/// Subtle pulsing ring around the current round dot.
private struct CurrentRoundPulse: View {
    @State private var isPulsing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Circle()
            .stroke(AppColors.lavender.opacity(0.3), lineWidth: 1.5)
            .frame(width: 18, height: 18)
            .scaleEffect(isPulsing ? 1.4 : 1)
            .opacity(isPulsing ? 0 : 0.5)
            .task {
                guard !reduceMotion else { return }
                withAnimation(
                    .easeOut(duration: 1.8)
                        .repeatForever(autoreverses: false)
                ) {
                    isPulsing = true
                }
            }
    }
}
