import SwiftUI

/// A single friend entry with session-start action.
struct FriendRow: View {
    let friend: FriendProfile
    let onStartSession: () -> Void

    var body: some View {
        HStack {
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

            Spacer()

            Button {
                onStartSession()
            } label: {
                Label("Study", systemImage: "play.fill")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColors.lavender)
            .controlSize(.small)
            .accessibilityLabel("Start study session with \(friend.displayName)")
        }
        .accessibilityElement(children: .combine)
    }
}
