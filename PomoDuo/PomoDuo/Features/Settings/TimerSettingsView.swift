import SwiftData
import SwiftUI

/// Allows users to customize Pomodoro durations and round count.
struct TimerSettingsView: View {
    @Query private var configurations: [TimerConfiguration]
    @Environment(\.modelContext) private var modelContext

    @State private var activeConfiguration: TimerConfiguration?

    var body: some View {
        Group {
            if let configuration = activeConfiguration {
                TimerSettingsForm(configuration: configuration)
            } else {
                ContentUnavailableView {
                    Label("Timer Settings", systemImage: "timer")
                } description: {
                    Text("Preparing your timer configuration.")
                }
            }
        }
        .navigationTitle("Timer Settings")
        .task(id: configurations.count) {
            await ensureConfigurationLoaded()
        }
    }

    @MainActor
    private func ensureConfigurationLoaded() async {
        if let existing = configurations.first {
            activeConfiguration = existing
            return
        }

        guard activeConfiguration == nil else { return }

        let newConfiguration = TimerConfiguration()
        modelContext.insert(newConfiguration)
        activeConfiguration = newConfiguration
    }
}

private struct TimerSettingsForm: View {
    @Bindable var configuration: TimerConfiguration

    var body: some View {
        Form {
            Section("Focus") {
                DurationPicker(
                    title: "Focus Duration",
                    selection: $configuration.focusDuration,
                    presets: TimerConfiguration.focusPresets
                )
            }

            Section("Breaks") {
                DurationPicker(
                    title: "Short Break",
                    selection: $configuration.shortBreakDuration,
                    presets: TimerConfiguration.shortBreakPresets
                )

                DurationPicker(
                    title: "Long Break",
                    selection: $configuration.longBreakDuration,
                    presets: TimerConfiguration.longBreakPresets
                )
            }

            Section("Rounds") {
                RoundPicker(
                    selection: $configuration.roundsBeforeLongBreak,
                    presets: TimerConfiguration.roundPresets
                )
            }
        }
    }
}

/// A picker row for selecting one duration from presets.
private struct DurationPicker: View {
    let title: String
    @Binding var selection: TimeInterval
    let presets: [TimeInterval]

    var body: some View {
        Picker(title, selection: $selection) {
            ForEach(presets, id: \.self) { duration in
                Text(TimerConfiguration.formatted(duration: duration))
                    .tag(duration)
            }
        }
    }
}

/// A picker row for selecting rounds before long break.
private struct RoundPicker: View {
    @Binding var selection: Int
    let presets: [Int]

    var body: some View {
        Picker("Rounds before long break", selection: $selection) {
            ForEach(presets, id: \.self) { count in
                Text("\(count) rounds")
                    .tag(count)
            }
        }
    }
}
