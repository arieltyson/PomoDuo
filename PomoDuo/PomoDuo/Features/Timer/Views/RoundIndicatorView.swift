//
//  RoundIndicatorView.swift
//  PomoDuo
//
//  Created by Codex on 2/15/26.
//

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

    var body: some View {
        Circle()
            .fill(dotColor)
            .frame(width: state == .current ? 10 : 8, height: state == .current ? 10 : 8)
            .scaleEffect(state == .current ? 1.2 : 1)
            .animation(.bouncy(duration: 0.35), value: state == .current)
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
