import SwiftUI

/// Presented when the user opens a `pomoduo://add-friend/{username}` deep link.
///
/// Looks up the target user, displays their profile, and offers to send
/// a friend request. Handles edge cases like self-lookup, unknown usernames,
/// and existing friendships.
struct AddFriendFromLinkView: View {
    let username: String
    let friendService: any FriendService

    @Environment(\.dismiss) private var dismiss
    @State private var phase = Phase.loading
    @State private var searchResult: UserSearchResult?

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .loading:
                    LoadingContent()

                case .found:
                    if let searchResult {
                        FoundContent(
                            result: searchResult,
                            onSend: { sendRequest() },
                            onDismiss: { dismiss() }
                        )
                    }

                case .notFound:
                    NotFoundContent(
                        username: username,
                        onDismiss: { dismiss() }
                    )

                case .isSelf:
                    SelfContent(onDismiss: { dismiss() })

                case .sending:
                    if let searchResult {
                        FoundContent(
                            result: searchResult,
                            onSend: { sendRequest() },
                            onDismiss: { dismiss() },
                            isSending: true
                        )
                    }

                case .sent:
                    SentContent(
                        displayName: searchResult?.displayName ?? username,
                        onDismiss: { dismiss() }
                    )

                case .error(let message):
                    ErrorContent(
                        message: message,
                        onRetry: { sendRequest() },
                        onDismiss: { dismiss() }
                    )
                }
            }
            .navigationTitle("Friend Invite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .task {
            await lookUpUser()
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func lookUpUser() async {
        do {
            let result = try await friendService.searchByUsername(username)
            if let result {
                searchResult = result
                phase = .found
            } else {
                // searchByUsername returns nil for self-lookups and unknown users.
                // Distinguish the two by checking availability.
                let isAvailable = try await friendService.isUsernameAvailable(username)
                phase = isAvailable ? .notFound : .isSelf
            }
        } catch {
            phase = .notFound
        }
    }

    private func sendRequest() {
        guard searchResult != nil else { return }
        phase = .sending

        Task {
            do {
                try await friendService.sendFriendRequest(toUsername: username)
                phase = .sent
            } catch let serviceError as FriendServiceError {
                phase = .error(serviceError.errorDescription ?? "Something went wrong.")
            } catch {
                phase = .error("Could not send friend request. Please try again.")
            }
        }
    }
}

// MARK: - Phase

private extension AddFriendFromLinkView {
    enum Phase {
        case loading
        case found
        case notFound
        case isSelf
        case sending
        case sent
        case error(String)
    }
}

// MARK: - Content Views

private struct LoadingContent: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Looking up user\u{2026}")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct FoundContent: View {
    let result: UserSearchResult
    let onSend: () -> Void
    let onDismiss: () -> Void
    var isSending = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ProfileAvatar(name: result.displayName)

            VStack(spacing: 4) {
                Text(result.displayName)
                    .font(.title2)
                    .fontWeight(.bold)

                Text("@\(result.username)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text("wants to connect with you on PomoDuo.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    onSend()
                } label: {
                    HStack(spacing: 8) {
                        if isSending {
                            ProgressView()
                                .tint(.white)
                        }
                        Text("Send Friend Request")
                    }
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.lavender)
                .controlSize(.large)
                .disabled(isSending)

                Button("Not Now") {
                    onDismiss()
                }
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
    }
}

private struct NotFoundContent: View {
    let username: String
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text("User Not Found")
                .font(.title3)
                .fontWeight(.semibold)

            Text("The username \"@\(username)\" doesn't exist or the account may have been deleted.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            Button("OK") { onDismiss() }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.lavender)
                .controlSize(.large)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
        }
    }
}

private struct SelfContent: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "face.smiling")
                .font(.system(size: 56))
                .foregroundStyle(AppColors.lavender)
                .accessibilityHidden(true)

            Text("That's You!")
                .font(.title3)
                .fontWeight(.semibold)

            Text("You can't send a friend request to yourself, but nice try.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            Button("OK") { onDismiss() }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.lavender)
                .controlSize(.large)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
        }
    }
}

private struct SentContent: View {
    let displayName: String
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(AppColors.success)
                .accessibilityHidden(true)

            Text("Request Sent!")
                .font(.title3)
                .fontWeight(.semibold)

            Text("\(displayName) will see your friend request next time they open PomoDuo.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            Button("Done") { onDismiss() }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.lavender)
                .controlSize(.large)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
        }
    }
}

private struct ErrorContent: View {
    let message: String
    let onRetry: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 56))
                .foregroundStyle(.orange)
                .accessibilityHidden(true)

            Text("Couldn't Send Request")
                .font(.title3)
                .fontWeight(.semibold)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 12) {
                Button("Try Again") { onRetry() }
                    .buttonStyle(.borderedProminent)
                    .tint(AppColors.lavender)
                    .controlSize(.large)

                Button("Cancel") { onDismiss() }
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
    }
}

// MARK: - Profile Avatar

private struct ProfileAvatar: View {
    let name: String

    var body: some View {
        Text(name.first.map(String.init) ?? "?")
            .font(.title)
            .bold()
            .foregroundStyle(.white)
            .frame(width: 72, height: 72)
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
}
