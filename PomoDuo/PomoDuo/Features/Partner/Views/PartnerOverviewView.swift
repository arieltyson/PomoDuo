import LinkPresentation
import SwiftUI

/// Lightweight overview displayed on the Partner tab when no session is active.
///
/// Shows inline friend requests with accept/decline, a compact friends
/// summary, a prominent session-start CTA, add-by-username entry,
/// sharing options, and quick-pair actions. Friend management (the full
/// list with swipe-to-remove) is one tap away via ``FriendsListView``.
struct PartnerOverviewView: View {
    let friendsViewModel: FriendsViewModel
    @Binding var pendingFriendRequestID: String?
    let onGenerateCode: () -> Void
    let onEnterCode: () -> Void
    let onShowUsernameSetup: () -> Void
    let onStartSession: (FriendProfile, PairedSessionConfig) -> Void

    @State private var isShowingStartSession = false
    @State private var isShowingAddFriend = false

    var body: some View {
        ScrollViewReader { proxy in
            List {
                if !friendsViewModel.incomingRequests.isEmpty {
                    FriendRequestsSection(
                        viewModel: friendsViewModel,
                        highlightedRequestID: friendsViewModel.highlightedRequestID
                    )
                }

                FriendsSummarySection(
                    friends: friendsViewModel.friends,
                    viewModel: friendsViewModel
                )

                StartSessionSection(
                    hasFriends: !friendsViewModel.friends.isEmpty,
                    onStartSession: { isShowingStartSession = true }
                )

                // Only render the "Share My Friend Link" affordance
                // when we have a *usable* username. A profile that
                // stored its `username` field as `""` (incomplete
                // claim, partial migration) would otherwise produce a
                // share link of `https://…/add-friend/`, which would
                // crash on tap when the receiver hits Firestore. The
                // ``UsernameNormalizer`` predicate keeps the gate in
                // lockstep with the service-layer guards.
                if let username = friendsViewModel.currentUsername,
                    let normalized = UsernameNormalizer.normalize(username)
                {
                    ShareProfileSection(
                        username: normalized,
                        senderName: friendsViewModel.currentDisplayName
                    )
                }

                ShareInviteSection(
                    senderName: friendsViewModel.currentDisplayName
                )

                QuickPairSection(
                    onGenerateCode: onGenerateCode,
                    onEnterCode: onEnterCode
                )
            }
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
            .onChange(of: pendingFriendRequestID) { _, requestID in
                guard let requestID else { return }
                friendsViewModel.highlightedRequestID = requestID
                pendingFriendRequestID = nil

                withAnimation {
                    proxy.scrollTo(requestID, anchor: .center)
                }

                Task {
                    try? await Task.sleep(for: .seconds(2))
                    withAnimation {
                        friendsViewModel.highlightedRequestID = nil
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingStartSession) {
            StartFriendSessionSheet(
                friends: friendsViewModel.friends
            ) { friend, config in
                isShowingStartSession = false
                onStartSession(friend, config)
            }
        }
        .sheet(isPresented: $isShowingAddFriend) {
            AddFriendView(viewModel: friendsViewModel)
        }
        .alert(
            "Error",
            isPresented: friendErrorIsPresented
        ) {
            Button("OK") { friendsViewModel.dismissError() }
        } message: {
            if let error = friendsViewModel.error {
                Text(error)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    handleAddFriend()
                } label: {
                    Image(systemName: "person.badge.plus")
                        .foregroundStyle(AppColors.lavender)
                }
                .accessibilityLabel("Add friend by username")
            }
        }
    }

    private func handleAddFriend() {
        if friendsViewModel.needsUsernameSetup {
            onShowUsernameSetup()
        } else {
            isShowingAddFriend = true
        }
    }

    private var friendErrorIsPresented: Binding<Bool> {
        Binding(
            get: { friendsViewModel.error != nil },
            set: { if !$0 { friendsViewModel.dismissError() } }
        )
    }
}

// MARK: - Friend Requests

private struct FriendRequestsSection: View {
    let viewModel: FriendsViewModel
    let highlightedRequestID: String?

    var body: some View {
        Section {
            ForEach(viewModel.incomingRequests) { request in
                FriendRequestRow(
                    request: request,
                    viewModel: viewModel,
                    isHighlighted: request.id == highlightedRequestID
                )
                .id(request.id)
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
    let isHighlighted: Bool

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
        .listRowBackground(
            isHighlighted
                ? AppColors.paleViolet.opacity(0.2)
                : nil
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Friend request from \(request.fromDisplayName)"
        )
    }
}

// MARK: - Friends Summary

private struct FriendsSummarySection: View {
    let friends: [FriendProfile]
    let viewModel: FriendsViewModel

    var body: some View {
        Section {
            NavigationLink {
                FriendsListView(viewModel: viewModel)
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
                .contentShape(.rect)
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

// MARK: - Share Profile

private struct ShareProfileSection: View {
    let username: String
    let senderName: String
    @State private var isShowingShareSheet = false

    var body: some View {
        Section {
            Button {
                isShowingShareSheet = true
            } label: {
                Label("Share My Friend Link", systemImage: "link")
                    .foregroundStyle(AppColors.lavender)
            }
            .sheet(isPresented: $isShowingShareSheet) {
                ProfileShareSheet(
                    username: username,
                    senderName: senderName
                )
                .presentationDetents([.medium, .large])
            }
        } header: {
            Text("Invite")
        } footer: {
            Text("Share a link so friends can send you a friend request directly.")
        }
    }
}

// MARK: - Share Invite

private struct ShareInviteSection: View {
    let senderName: String
    @State private var isShowingShareSheet = false

    var body: some View {
        Section {
            Button {
                isShowingShareSheet = true
            } label: {
                Label("Invite Friends to PomoDuo", systemImage: "square.and.arrow.up")
                    .foregroundStyle(AppColors.lavender)
            }
            .sheet(isPresented: $isShowingShareSheet) {
                RichShareSheet(
                    senderName: senderName,
                    appStoreURL: appStoreURL
                )
                .presentationDetents([.medium, .large])
            }
        } footer: {
            Text("Share PomoDuo with friends who haven\u{2019}t downloaded it yet.")
        }
    }

    private var appStoreURL: URL {
        URL(string: "https://apps.apple.com/app/pomo-duo/id6759349583")
            ?? URL(string: "https://apple.com")!
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

// MARK: - Profile Share Sheet

private struct ProfileShareSheet: UIViewControllerRepresentable {
    let username: String
    let senderName: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let itemSource = ProfileActivityItemSource(
            username: username,
            senderName: senderName,
            iconImage: renderShareIcon()
        )
        return UIActivityViewController(
            activityItems: [itemSource],
            applicationActivities: nil
        )
    }

    func updateUIViewController(
        _ uiViewController: UIActivityViewController,
        context: Context
    ) {}

    @MainActor
    private func renderShareIcon() -> UIImage {
        let renderer = ImageRenderer(content: ProfileShareIconView())
        renderer.scale = 3
        return renderer.uiImage ?? UIImage(systemName: "person.badge.plus")!
    }
}

private final class ProfileActivityItemSource: NSObject, UIActivityItemSource {
    let username: String
    let senderName: String
    let iconImage: UIImage

    /// Single HTTPS link that works as a Universal Link when the app is
    /// installed and falls back to a landing page when it is not.
    private var friendLink: URL {
        DeepLinkRouter.addFriendURL(username: username)
    }

    init(
        username: String,
        senderName: String,
        iconImage: UIImage
    ) {
        self.username = username
        self.senderName = senderName
        self.iconImage = iconImage
    }

    func activityViewControllerPlaceholderItem(
        _ activityViewController: UIActivityViewController
    ) -> Any {
        friendLink
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        let name = senderName.isEmpty ? "Someone" : senderName
        return "\(name) wants to be your study friend on PomoDuo! \(friendLink.absoluteString)"
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        subjectForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        "Add Me on PomoDuo"
    }

    func activityViewControllerLinkMetadata(
        _ activityViewController: UIActivityViewController
    ) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.originalURL = friendLink
        metadata.url = friendLink
        metadata.title = "Add Me on PomoDuo \u{2014} @\(username)"
        metadata.iconProvider = NSItemProvider(object: iconImage)
        return metadata
    }
}

private struct ProfileShareIconView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22)
                .fill(
                    LinearGradient(
                        colors: [AppColors.lavender, AppColors.lilac],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 120, height: 120)

            Image(systemName: "person.badge.plus")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Rich Share Sheet

private struct RichShareSheet: UIViewControllerRepresentable {
    let senderName: String
    let appStoreURL: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let itemSource = InviteActivityItemSource(
            senderName: senderName,
            appStoreURL: appStoreURL,
            iconImage: renderShareIcon()
        )
        return UIActivityViewController(
            activityItems: [itemSource],
            applicationActivities: nil
        )
    }

    func updateUIViewController(
        _ uiViewController: UIActivityViewController,
        context: Context
    ) {}

    @MainActor
    private func renderShareIcon() -> UIImage {
        let renderer = ImageRenderer(content: SharePreviewIconView())
        renderer.scale = 3
        return renderer.uiImage ?? UIImage(systemName: "person.2.fill")!
    }
}

private final class InviteActivityItemSource: NSObject, UIActivityItemSource {
    let senderName: String
    let appStoreURL: URL
    let iconImage: UIImage

    init(senderName: String, appStoreURL: URL, iconImage: UIImage) {
        self.senderName = senderName
        self.appStoreURL = appStoreURL
        self.iconImage = iconImage
    }

    func activityViewControllerPlaceholderItem(
        _ activityViewController: UIActivityViewController
    ) -> Any {
        appStoreURL
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        if senderName.isEmpty {
            "Join me on PomoDuo and let\u{2019}s crush our study goals together!\n\(appStoreURL.absoluteString)"
        } else {
            "\(senderName) wants to lock in with you on PomoDuo \u{2014} a study timer built for accountability. Download it and let\u{2019}s crush our goals together!\n\(appStoreURL.absoluteString)"
        }
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        subjectForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        "Lock In With Me on PomoDuo"
    }

    func activityViewControllerLinkMetadata(
        _ activityViewController: UIActivityViewController
    ) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.originalURL = appStoreURL
        metadata.url = appStoreURL
        metadata.title = "Lock In With Me on PomoDuo"
        metadata.iconProvider = NSItemProvider(object: iconImage)
        return metadata
    }
}

private struct SharePreviewIconView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22)
                .fill(
                    LinearGradient(
                        colors: [AppColors.lavender, AppColors.lilac],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 120, height: 120)

            Image(systemName: "person.2.fill")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
}
