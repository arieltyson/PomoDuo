import SwiftUI

/// Lightweight overview displayed on the Partner tab when no session is active.
///
/// Shows a compact friends summary, a prominent session-start CTA, and
/// quick-pair options. Friend management is one tap away via a dedicated
/// ``FriendsListView`` pushed onto the navigation stack.
struct PartnerOverviewView: View {
    let friendsViewModel: FriendsViewModel
    @Binding var pendingFriendRequestID: String?
    let onGenerateCode: () -> Void
    let onEnterCode: () -> Void
    let onShowUsernameSetup: () -> Void
    let onStartSession: (FriendProfile, PairedSessionConfig) -> Void

    @State private var isShowingStartSession = false

    var body: some View {
        List {
            if !friendsViewModel.incomingRequests.isEmpty {
                FriendRequestsSummaryRow(
                    count: friendsViewModel.incomingRequests.count,
                    friendsViewModel: friendsViewModel,
                    pendingFriendRequestID: $pendingFriendRequestID,
                    onShowUsernameSetup: onShowUsernameSetup
                )
            }

            FriendsSummarySection(
                friends: friendsViewModel.friends,
                needsUsername: friendsViewModel.needsUsernameSetup,
                friendsViewModel: friendsViewModel,
                pendingFriendRequestID: $pendingFriendRequestID,
                onShowUsernameSetup: onShowUsernameSetup
            )

            StartSessionSection(
                hasFriends: !friendsViewModel.friends.isEmpty,
                onStartSession: { isShowingStartSession = true }
            )

            QuickPairSection(
                onGenerateCode: onGenerateCode,
                onEnterCode: onEnterCode
            )
        }
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
        .sheet(isPresented: $isShowingStartSession) {
            StartFriendSessionSheet(
                friends: friendsViewModel.friends
            ) { friend, config in
                isShowingStartSession = false
                onStartSession(friend, config)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    FriendsListView(
                        viewModel: friendsViewModel,
                        pendingFriendRequestID: $pendingFriendRequestID,
                        onShowUsernameSetup: onShowUsernameSetup
                    )
                } label: {
                    Image(systemName: "person.badge.plus")
                        .foregroundStyle(AppColors.lavender)
                }
                .accessibilityLabel("Manage friends")
            }
        }
    }
}

// MARK: - Friend Requests Summary

private struct FriendRequestsSummaryRow: View {
    let count: Int
    let friendsViewModel: FriendsViewModel
    @Binding var pendingFriendRequestID: String?
    let onShowUsernameSetup: () -> Void

    var body: some View {
        Section {
            NavigationLink {
                FriendsListView(
                    viewModel: friendsViewModel,
                    pendingFriendRequestID: $pendingFriendRequestID,
                    onShowUsernameSetup: onShowUsernameSetup
                )
            } label: {
                Label {
                    HStack {
                        Text("Friend Requests")
                            .font(.body)

                        Spacer()

                        Text("\(count)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(AppColors.lavender, in: .capsule)
                    }
                } icon: {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .foregroundStyle(AppColors.lavender)
                }
            }
            .accessibilityLabel("\(count) pending friend requests")
            .accessibilityHint("Opens the friends list to review requests.")
        }
    }
}

// MARK: - Friends Summary

private struct FriendsSummarySection: View {
    let friends: [FriendProfile]
    let needsUsername: Bool
    let friendsViewModel: FriendsViewModel
    @Binding var pendingFriendRequestID: String?
    let onShowUsernameSetup: () -> Void

    var body: some View {
        Section {
            if friends.isEmpty {
                EmptyFriendsRow(
                    needsUsername: needsUsername,
                    friendsViewModel: friendsViewModel,
                    pendingFriendRequestID: $pendingFriendRequestID,
                    onShowUsernameSetup: onShowUsernameSetup
                )
            } else {
                NavigationLink {
                    FriendsListView(
                        viewModel: friendsViewModel,
                        pendingFriendRequestID: $pendingFriendRequestID,
                        onShowUsernameSetup: onShowUsernameSetup
                    )
                } label: {
                    Label {
                        HStack {
                            Text("Friends")
                                .font(.body)

                            Spacer()

                            Text("\(friends.count)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "person.2.fill")
                            .foregroundStyle(AppColors.lavender)
                    }
                }
                .accessibilityLabel("\(friends.count) friends")
                .accessibilityHint("Opens your friends list.")
            }
        } header: {
            Label("Friends", systemImage: "person.2.fill")
        }
    }
}

private struct EmptyFriendsRow: View {
    let needsUsername: Bool
    let friendsViewModel: FriendsViewModel
    @Binding var pendingFriendRequestID: String?
    let onShowUsernameSetup: () -> Void

    var body: some View {
        NavigationLink {
            FriendsListView(
                viewModel: friendsViewModel,
                pendingFriendRequestID: $pendingFriendRequestID,
                onShowUsernameSetup: onShowUsernameSetup
            )
        } label: {
            VStack(spacing: 12) {
                Image(systemName: "person.2.slash")
                    .font(.system(size: 32))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)

                Text("No Friends Yet")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(
                    needsUsername
                        ? "Set up a username to add friends."
                        : "Add friends to start focus sessions together."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
        .accessibilityLabel("No friends yet. Tap to add friends.")
    }
}

// MARK: - Start Session CTA

private struct StartSessionSection: View {
    let hasFriends: Bool
    let onStartSession: () -> Void

    var body: some View {
        Section {
            Button {
                onStartSession()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "person.2.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(
                            LinearGradient(
                                colors: [AppColors.lavender, AppColors.lilac],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: .circle
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Start Focus Session")
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)

                        Text(
                            hasFriends
                                ? "Choose a friend and lock in together."
                                : "Add a friend first, then start a session."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .disabled(!hasFriends)
            .opacity(hasFriends ? 1 : 0.5)
            .accessibilityLabel("Start paired focus session")
            .accessibilityHint(
                hasFriends
                    ? "Opens session setup to choose a friend and configure the timer."
                    : "Add a friend first to start a paired session."
            )
        } header: {
            Text("Focus Together")
        }
    }
}

// MARK: - Quick Pair

private struct QuickPairSection: View {
    let onGenerateCode: () -> Void
    let onEnterCode: () -> Void

    var body: some View {
        Section {
            Button {
                onGenerateCode()
            } label: {
                Label("Generate Pairing Code", systemImage: "qrcode")
                    .foregroundStyle(AppColors.lavender)
            }

            Button {
                onEnterCode()
            } label: {
                Label("Enter Partner\u{2019}s Code", systemImage: "keyboard")
                    .foregroundStyle(AppColors.lavender)
            }
        } header: {
            Text("Quick Pair")
        } footer: {
            Text("Pair with anyone using a 6-digit code for a one-time session.")
        }
    }
}
