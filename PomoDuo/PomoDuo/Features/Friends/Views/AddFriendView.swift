import SwiftUI

/// Sheet for searching and adding friends by username.
struct AddFriendView: View {
    let viewModel: FriendsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                SearchFieldSection(viewModel: viewModel)

                if viewModel.isSearching {
                    ProgressView("Searching…")
                        .frame(maxHeight: .infinity)
                } else if let result = viewModel.searchResult {
                    SearchResultCard(
                        result: result,
                        isSending: viewModel.isSendingRequest,
                        onSendRequest: {
                            Task {
                                await viewModel.sendFriendRequest()
                                if viewModel.error == nil {
                                    dismiss()
                                }
                            }
                        }
                    )
                    Spacer()
                } else if viewModel.searchFoundNoResults {
                    ContentUnavailableView(
                        "No User Found",
                        systemImage: "person.slash",
                        description: Text(
                            "No one with that username exists. Check the spelling and try again."
                        )
                    )
                } else {
                    AddFriendPlaceholder()
                }
            }
            .padding()
            .navigationTitle("Add Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

private struct SearchFieldSection: View {
    @Bindable var viewModel: FriendsViewModel

    var body: some View {
        HStack {
            TextField("Search by username", text: $viewModel.searchQuery)
                .textContentType(.username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit {
                    guard !isSearchButtonDisabled else { return }
                    Task { await viewModel.searchForUser() }
                }

            Button {
                Task { await viewModel.searchForUser() }
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .disabled(isSearchButtonDisabled)
            .accessibilityLabel("Search")
            .accessibilityHint(
                viewModel.isSearching
                    ? "Search in progress."
                    : "Searches for a user by username."
            )
        }
        .padding(12)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
    }

    /// Single source of truth for whether the query can be submitted.
    ///
    /// The TextField's `onSubmit` and the Button's `disabled` read the same
    /// value so a blank query or an already in-flight search is blocked
    /// from both paths — the view model's newest-wins cancellation still
    /// catches anything that slips through timing-wise.
    private var isSearchButtonDisabled: Bool {
        viewModel.isSearching
            || viewModel.searchQuery
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty
    }
}

private struct SearchResultCard: View {
    let result: UserSearchResult
    let isSending: Bool
    let onSendRequest: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            FriendInitialAvatar(name: result.displayName)
                .scaleEffect(1.5)

            VStack(spacing: 4) {
                Text(result.displayName)
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("@\(result.username)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button {
                onSendRequest()
            } label: {
                HStack {
                    if isSending {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(isSending ? "Sending…" : "Send Friend Request")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColors.lavender)
            .controlSize(.large)
            .disabled(isSending)
        }
        .padding(24)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(result.displayName), @\(result.username)"
        )
    }
}

private struct AddFriendPlaceholder: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.badge.plus")
                .font(.largeTitle)
                .foregroundStyle(AppColors.lavender)
                .padding()
                .background(
                    AppColors.paleViolet.opacity(0.25),
                    in: .circle
                )

            Text("Find Your Study Partners")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Search for friends by their username to send a friend request.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}
