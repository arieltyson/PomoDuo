import SwiftUI

/// Dedicated friends list screen pushed from the Partner overview.
///
/// Shows only the user's friends with swipe-to-remove for management.
/// All other actions (requests, invites, sharing) live on the main
/// Partner tab for easy access.
struct FriendsListView: View {
    let viewModel: FriendsViewModel

    var body: some View {
        List {
            if viewModel.friends.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)

                        VStack(spacing: 4) {
                            Text("No Friends Yet")
                                .font(.headline)

                            Text("Add friends from the Partner tab to see them here.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
                .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(viewModel.friends) { friend in
                        FriendRow(friend: friend)
                            .swipeActions(edge: .trailing) {
                                Button("Remove", role: .destructive) {
                                    Task { await viewModel.removeFriend(friend) }
                                }
                            }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
        .navigationTitle("Friends")
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
