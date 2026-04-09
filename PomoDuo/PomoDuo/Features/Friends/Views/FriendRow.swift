import SwiftUI

/// A single friend entry displaying name and username.
///
/// Used in the dedicated ``FriendsListView`` for browsing and managing
/// friends. Session-start actions are handled by the
/// ``StartFriendSessionSheet`` from the Partner overview instead.
struct FriendRow: View {
    let friend: FriendProfile

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
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(friend.displayName), @\(friend.username)")
    }
}
