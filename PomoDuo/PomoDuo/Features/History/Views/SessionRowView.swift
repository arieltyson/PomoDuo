//
//  SessionRowView.swift
//  PomoDuo
//
//  Created by Codex on 2/15/26.
//

import SwiftUI

/// Row representation of a completed focus session.
struct SessionRowView: View {
    let session: CompletedSession

    var body: some View {
        HStack {
            SessionTypeIcon(sessionType: session.sessionType)

            VStack(alignment: .leading) {
                Text("\(session.focusMinutes) min focus")
                    .font(.subheadline)
                    .bold()

                Text("Round \(session.roundNumber) of \(session.totalRounds)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing) {
                Text(session.startedAt, format: .dateTime.hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(session.startedAt, format: .dateTime.month(.abbreviated).day())
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        let typeLabel = session.sessionType == .paired ? "Paired" : "Solo"
        return "\(typeLabel) focus, \(session.focusMinutes) minutes, round \(session.roundNumber) of \(session.totalRounds)"
    }
}

private struct SessionTypeIcon: View {
    let sessionType: CompletedSession.SessionType

    var body: some View {
        Image(systemName: sessionType == .paired ? "person.2.fill" : "person.fill")
            .foregroundStyle(sessionType == .paired ? AppColors.lilac : AppColors.lavender)
            .frame(width: 32, height: 32)
            .background(AppColors.paleViolet.opacity(0.2))
            .clipShape(.circle)
    }
}
