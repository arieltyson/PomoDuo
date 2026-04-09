import SwiftData
import SwiftUI

/// Unified sheet for selecting a friend and configuring a paired session.
///
/// Combines friend selection with session configuration in a single
/// form so the user can pick a partner and start in one fluid step.
struct StartFriendSessionSheet: View {
    let friends: [FriendProfile]
    let onStart: (FriendProfile, PairedSessionConfig) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query private var configurations: [TimerConfiguration]

    @State private var selectedFriend: FriendProfile?
    @State private var focusDuration: TimeInterval = 25 * 60
    @State private var shortBreakDuration: TimeInterval = 5 * 60
    @State private var longBreakDuration: TimeInterval = 15 * 60
    @State private var totalRounds: Int = 4
    @State private var hasLoadedDefaults = false

    var body: some View {
        NavigationStack {
            Form {
                PartnerPickerSection(
                    friends: friends,
                    selectedFriend: $selectedFriend
                )

                SessionConfigSections(
                    focusDuration: $focusDuration,
                    shortBreakDuration: $shortBreakDuration,
                    longBreakDuration: $longBreakDuration,
                    totalRounds: $totalRounds
                )

                SessionTotalSection(
                    focusDuration: focusDuration,
                    shortBreakDuration: shortBreakDuration,
                    longBreakDuration: longBreakDuration,
                    totalRounds: totalRounds
                )
            }
            .navigationTitle("Start Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        guard let friend = selectedFriend else { return }
                        let config = PairedSessionConfig(
                            focusDuration: focusDuration,
                            shortBreakDuration: shortBreakDuration,
                            longBreakDuration: longBreakDuration,
                            totalRounds: totalRounds
                        )
                        dismiss()
                        onStart(friend, config)
                    }
                    .fontWeight(.semibold)
                    .tint(AppColors.lavender)
                    .disabled(selectedFriend == nil)
                }
            }
        }
        .presentationDetents([.large])
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

// MARK: - Partner Picker

private struct PartnerPickerSection: View {
    let friends: [FriendProfile]
    @Binding var selectedFriend: FriendProfile?

    var body: some View {
        Section {
            ForEach(friends) { friend in
                FriendSelectionRow(
                    friend: friend,
                    isSelected: selectedFriend?.id == friend.id,
                    onSelect: { selectedFriend = friend }
                )
            }
        } header: {
            Text("Study With")
        } footer: {
            if friends.isEmpty {
                Text("Add friends from the Friends screen to start a paired session.")
            }
        }
    }
}

private struct FriendSelectionRow: View {
    let friend: FriendProfile
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack(spacing: 12) {
                FriendInitialAvatar(name: friend.displayName)

                VStack(alignment: .leading, spacing: 2) {
                    Text(friend.displayName)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)

                    if !friend.username.isEmpty {
                        Text("@\(friend.username)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(
                    systemName: isSelected
                        ? "checkmark.circle.fill"
                        : "circle"
                )
                .font(.title3)
                .foregroundStyle(isSelected ? AnyShapeStyle(AppColors.lavender) : AnyShapeStyle(.tertiary))
                .animation(.easeInOut(duration: 0.15), value: isSelected)
            }
        }
        .buttonStyle(.plain)
        .listRowBackground(
            isSelected
                ? AppColors.paleViolet.opacity(0.15)
                : nil
        )
        .accessibilityLabel("\(friend.displayName)")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Session Configuration

private struct SessionConfigSections: View {
    @Binding var focusDuration: TimeInterval
    @Binding var shortBreakDuration: TimeInterval
    @Binding var longBreakDuration: TimeInterval
    @Binding var totalRounds: Int

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

// MARK: - Session Total

private struct SessionTotalSection: View {
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
            .accessibilityLabel(
                "Total session duration approximately \(totalSessionMinutes) minutes"
            )
        } footer: {
            Text(
                "Includes \(totalRounds) focus rounds, \(totalRounds - 1) short breaks, and 1 long break."
            )
        }
    }
}
