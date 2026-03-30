import SwiftData
import SwiftUI

/// Configuration to start a paired session, returned from the config sheet.
struct PairedSessionConfig: Equatable, Sendable {
    var focusDuration: TimeInterval
    var shortBreakDuration: TimeInterval
    var longBreakDuration: TimeInterval
    var totalRounds: Int
}

/// Sheet allowing the user to configure durations before starting
/// a paired focus session.
///
/// Pre-fills with the user's saved ``TimerConfiguration`` so paired
/// and solo sessions stay consistent by default. Any adjustments
/// made here apply only to the upcoming paired session and do not
/// alter the persisted solo timer settings.
struct PairedSessionConfigSheet: View {
    let partnerName: String
    let onStart: (PairedSessionConfig) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query private var configurations: [TimerConfiguration]

    @State private var focusDuration: TimeInterval = 25 * 60
    @State private var shortBreakDuration: TimeInterval = 5 * 60
    @State private var longBreakDuration: TimeInterval = 15 * 60
    @State private var totalRounds: Int = 4
    @State private var hasLoadedDefaults = false

    var body: some View {
        NavigationStack {
            Form {
                HeaderSection(partnerName: partnerName)

                FocusSection(focusDuration: $focusDuration)

                BreakSection(
                    shortBreakDuration: $shortBreakDuration,
                    longBreakDuration: $longBreakDuration
                )

                RoundsSection(totalRounds: $totalRounds)

                SessionSummarySection(
                    focusDuration: focusDuration,
                    shortBreakDuration: shortBreakDuration,
                    longBreakDuration: longBreakDuration,
                    totalRounds: totalRounds
                )
            }
            .navigationTitle("Session Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        let config = PairedSessionConfig(
                            focusDuration: focusDuration,
                            shortBreakDuration: shortBreakDuration,
                            longBreakDuration: longBreakDuration,
                            totalRounds: totalRounds
                        )
                        dismiss()
                        onStart(config)
                    }
                    .fontWeight(.semibold)
                    .tint(AppColors.lavender)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task {
            guard !hasLoadedDefaults else { return }
            if let saved = configurations.first {
                focusDuration = saved.focusDuration
                shortBreakDuration = saved.shortBreakDuration
                longBreakDuration = saved.longBreakDuration
                totalRounds = saved.roundsBeforeLongBreak
            }
            hasLoadedDefaults = true
        }
    }
}

// MARK: - Sections

private struct HeaderSection: View {
    let partnerName: String

    var body: some View {
        Section {
            HStack(spacing: 12) {
                Text(partnerName.first.map(String.init) ?? "?")
                    .font(.callout)
                    .bold()
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(
                        LinearGradient(
                            colors: [AppColors.lavender, AppColors.lilac],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: .circle
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Study with \(partnerName)")
                        .font(.headline)

                    Text("Configure this session before starting.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct FocusSection: View {
    @Binding var focusDuration: TimeInterval

    var body: some View {
        Section("Focus") {
            Picker("Focus Duration", selection: $focusDuration) {
                ForEach(TimerConfiguration.focusPresets, id: \.self) { duration in
                    Text(TimerConfiguration.formatted(duration: duration))
                        .tag(duration)
                }
            }
            .accessibilityHint("Sets the focus period length for each round.")
        }
    }
}

private struct BreakSection: View {
    @Binding var shortBreakDuration: TimeInterval
    @Binding var longBreakDuration: TimeInterval

    var body: some View {
        Section("Breaks") {
            Picker("Short Break", selection: $shortBreakDuration) {
                ForEach(TimerConfiguration.shortBreakPresets, id: \.self) { duration in
                    Text(TimerConfiguration.formatted(duration: duration))
                        .tag(duration)
                }
            }
            .accessibilityHint("Sets the short break length between rounds.")

            Picker("Long Break", selection: $longBreakDuration) {
                ForEach(TimerConfiguration.longBreakPresets, id: \.self) { duration in
                    Text(TimerConfiguration.formatted(duration: duration))
                        .tag(duration)
                }
            }
            .accessibilityHint("Sets the long break length after all rounds.")
        }
    }
}

private struct RoundsSection: View {
    @Binding var totalRounds: Int

    var body: some View {
        Section("Rounds") {
            Picker("Rounds before long break", selection: $totalRounds) {
                ForEach(TimerConfiguration.roundPresets, id: \.self) { count in
                    Text("\(count) rounds")
                        .tag(count)
                }
            }
            .accessibilityHint("Sets how many focus rounds before a long break.")
        }
    }
}

private struct SessionSummarySection: View {
    let focusDuration: TimeInterval
    let shortBreakDuration: TimeInterval
    let longBreakDuration: TimeInterval
    let totalRounds: Int

    private var totalSessionMinutes: Int {
        let focusTotal = focusDuration * Double(totalRounds)
        let shortBreakTotal = shortBreakDuration * Double(max(0, totalRounds - 1))
        let totalSeconds = focusTotal + shortBreakTotal + longBreakDuration
        return Int(totalSeconds / 60)
    }

    var body: some View {
        Section {
            HStack {
                Label("Total Session", systemImage: "clock")
                    .foregroundStyle(.secondary)
                Spacer()
                Text("~\(totalSessionMinutes) min")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(AppColors.lavender)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Total session duration approximately \(totalSessionMinutes) minutes")
        } footer: {
            Text("Includes \(totalRounds) focus rounds, \(totalRounds - 1) short breaks, and 1 long break.")
        }
    }
}
