import SwiftUI

/// Main friends list displayed in the Partner tab when no session is active.
struct FriendsListView: View {
    let viewModel: FriendsViewModel
    let onStartSession: (FriendProfile) -> Void
    let onGenerateCode: () -> Void
    let onEnterCode: () -> Void
    let onShowUsernameSetup: () -> Void

    @State private var isShowingAddFriend = false

    var body: some View {
        List {
            if !viewModel.incomingRequests.isEmpty {
                FriendRequestsSection(viewModel: viewModel)
            }

            if viewModel.friends.isEmpty {
                EmptyFriendsSection(
                    needsUsername: viewModel.needsUsernameSetup,
                    onAddFriend: { handleAddFriend() },
                    onSetupUsername: onShowUsernameSetup
                )
            } else {
                FriendsSection(
                    friends: viewModel.friends,
                    viewModel: viewModel,
                    onStartSession: onStartSession
                )
            }

            QuickPairSection(
                onGenerateCode: onGenerateCode,
                onEnterCode: onEnterCode
            )

            ShareInviteSection()
        }
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add Friend", systemImage: "person.badge.plus") {
                    handleAddFriend()
                }
                .tint(AppColors.lavender)
            }
        }
        .sheet(isPresented: $isShowingAddFriend) {
            AddFriendView(viewModel: viewModel)
        }
        .alert(
            "Error",
            isPresented: friendErrorIsPresented
        ) {
            Button("OK") { viewModel.dismissError() }
        } message: {
            if let error = viewModel.error {
                Text(error)
            }
        }
    }

    private func handleAddFriend() {
        if viewModel.needsUsernameSetup {
            onShowUsernameSetup()
        } else {
            isShowingAddFriend = true
        }
    }

    private var friendErrorIsPresented: Binding<Bool> {
        Binding(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.dismissError() } }
        )
    }
}

// MARK: - Sections

private struct FriendRequestsSection: View {
    let viewModel: FriendsViewModel

    var body: some View {
        Section {
            ForEach(viewModel.incomingRequests) { request in
                FriendRequestRow(request: request, viewModel: viewModel)
            }
        } header: {
            Label(
                "Friend Requests (\(viewModel.incomingRequests.count))",
                systemImage: "person.crop.circle.badge.plus"
            )
        }
    }
}

private struct FriendRequestRow: View {
    let request: FriendRequest
    let viewModel: FriendsViewModel

    var body: some View {
        HStack {
            FriendInitialAvatar(name: request.fromDisplayName)

            VStack(alignment: .leading, spacing: 2) {
                Text(request.fromDisplayName)
                    .font(.body)
                    .fontWeight(.medium)

                if !request.fromUsername.isEmpty {
                    Text("@\(request.fromUsername)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    Task { await viewModel.acceptRequest(request) }
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(AppColors.success)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Accept")

                Button {
                    Task { await viewModel.declineRequest(request) }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Decline")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Friend request from \(request.fromDisplayName)"
        )
    }
}

private struct FriendsSection: View {
    let friends: [FriendProfile]
    let viewModel: FriendsViewModel
    let onStartSession: (FriendProfile) -> Void

    var body: some View {
        Section {
            ForEach(friends) { friend in
                FriendRow(
                    friend: friend,
                    onStartSession: { onStartSession(friend) }
                )
                .swipeActions(edge: .trailing) {
                    Button("Remove", role: .destructive) {
                        Task { await viewModel.removeFriend(friend) }
                    }
                }
            }
        } header: {
            Label("Friends", systemImage: "person.2.fill")
        }
    }
}

private struct EmptyFriendsSection: View {
    let needsUsername: Bool
    let onAddFriend: () -> Void
    let onSetupUsername: () -> Void

    var body: some View {
        Section {
            VStack(spacing: 16) {
                Image(systemName: "person.2.slash")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                VStack(spacing: 4) {
                    Text("No Friends Yet")
                        .font(.headline)

                    Text(
                        needsUsername
                            ? "Set up a username to add friends."
                            : "Add friends to start focus sessions together."
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                }

                if !needsUsername {
                    Button("Add a Friend") {
                        onAddFriend()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppColors.lavender)
                    .controlSize(.regular)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        }
        .listRowBackground(Color.clear)
    }
}

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
                Label("Enter Partner's Code", systemImage: "keyboard")
                    .foregroundStyle(AppColors.lavender)
            }
        } header: {
            Text("Quick Pair")
        } footer: {
            Text("Pair with anyone using a 6-digit code for a one-time session.")
        }
    }
}

private struct ShareInviteSection: View {
    var body: some View {
        Section {
            ShareLink(
                item: appStoreURL,
                message: Text("Let's study together on PomoDuo!")
            ) {
                Label("Invite Friends to PomoDuo", systemImage: "square.and.arrow.up")
                    .foregroundStyle(AppColors.lavender)
            }
        } footer: {
            Text("Share PomoDuo with friends who haven't downloaded it yet.")
        }
    }

    private var appStoreURL: URL {
        URL(string: "https://apps.apple.com/app/pomoduo-study-together/id6744396498")
            ?? URL(string: "https://apple.com")!
    }
}

// MARK: - Shared Components

struct FriendInitialAvatar: View {
    let name: String

    var body: some View {
        Text(initial)
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
    }

    private var initial: String {
        name.first.map(String.init) ?? "?"
    }
}
