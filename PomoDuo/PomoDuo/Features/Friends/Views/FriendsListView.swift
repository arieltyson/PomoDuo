import SwiftUI

/// Main friends list displayed in the Partner tab when no session is active.
struct FriendsListView: View {
    let viewModel: FriendsViewModel
    let onStartSession: (FriendProfile) -> Void

    @State private var isShowingAddFriend = false

    var body: some View {
        List {
            if !viewModel.incomingRequests.isEmpty {
                FriendRequestsSection(viewModel: viewModel)
            }

            if viewModel.friends.isEmpty {
                EmptyFriendsSection(
                    onAddFriend: { isShowingAddFriend = true }
                )
            } else {
                FriendsSection(
                    friends: viewModel.friends,
                    viewModel: viewModel,
                    onStartSession: onStartSession
                )
            }

            QuickPairSection()

            ShareInviteSection()
        }
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add Friend", systemImage: "person.badge.plus") {
                    isShowingAddFriend = true
                }
                .tint(AppColors.lavender)
                .disabled(viewModel.needsUsernameSetup)
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
    let onAddFriend: () -> Void

    var body: some View {
        Section {
            ContentUnavailableView {
                Label("No Friends Yet", systemImage: "person.2.slash")
            } description: {
                Text("Add friends to start focus sessions together.")
            } actions: {
                Button("Add a Friend", systemImage: "person.badge.plus") {
                    onAddFriend()
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.lavender)
            }
        }
        .listRowBackground(Color.clear)
    }
}

private struct QuickPairSection: View {
    var body: some View {
        Section {
            NavigationLink {
                QuickPairExplanationView()
            } label: {
                Label("Quick Pair with Code", systemImage: "qrcode")
                    .foregroundStyle(AppColors.lavender)
            }
        } header: {
            Text("One-Time Sessions")
        } footer: {
            Text("Pair with anyone using a 6-digit code for a quick session.")
        }
    }
}

private struct QuickPairExplanationView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Quick Pair", systemImage: "qrcode")
        } description: {
            Text("Use the original code-based pairing for one-time sessions with anyone.")
        }
        .navigationTitle("Quick Pair")
        .navigationBarTitleDisplayMode(.inline)
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
