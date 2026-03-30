import SwiftUI

/// A single friend entry with session-start action.
///
/// Uses a compact icon-only trailing button so the row stays clean
/// even when the friends list grows long. The friend's name and
/// username remain the visual focus, following Apple HIG list patterns.
struct FriendRow: View {
    let friend: FriendProfile
    let onStartSession: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            FriendInitialAvatar(name: friend.displayName)

            VStack(alignment: .leading, spacing: 2) {
                Text(friend.displayName)
                    .font(.body)
                    .fontWeight(.medium)

                if !friend.username.isEmpty {
                    Text("@\(friend.username)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            Button {
                onStartSession()
            } label: {
                Image(systemName: "play.fill")
                    .font(.caption)
                    .foregroundStyle(AppColors.lavender)
                    .frame(width: 32, height: 32)
                    .background(AppColors.lavender.opacity(0.14), in: .circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Start study session with \(friend.displayName)")
        }
        .accessibilityElement(children: .combine)
    }
}
