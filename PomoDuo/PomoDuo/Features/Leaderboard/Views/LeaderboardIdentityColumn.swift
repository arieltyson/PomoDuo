import SwiftUI

struct LeaderboardIdentityColumn: View {
    let displayName: String
    let username: String
    let isCurrentUser: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if isCurrentUser {
                Text(displayName)
                    .font(.body)
                    .bold()
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(displayName)
                    .font(.body)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !username.isEmpty || isCurrentUser {
                HStack(spacing: 6) {
                    if !username.isEmpty {
                        Text("@\(username)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    if isCurrentUser {
                        Text("You")
                            .font(.caption2)
                            .bold()
                            .foregroundStyle(AppColors.lavender)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                AppColors.paleViolet.opacity(0.3),
                                in: .capsule
                            )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .layoutPriority(1)
    }
}
