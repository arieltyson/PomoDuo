import SwiftUI

/// A single friend entry with session-start action.
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
                Label("Study", systemImage: "book.fill")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .buttonStyle(StudyButtonStyle())
            .accessibilityLabel("Start study session with \(friend.displayName)")
        }
        .accessibilityElement(children: .combine)
    }
}

/// Branded capsule button with a lavender gradient fill.
private struct StudyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                LinearGradient(
                    colors: [AppColors.lavender, AppColors.lilac],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: .capsule
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
