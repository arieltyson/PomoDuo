import LinkPresentation
import SwiftUI

/// Main friends list displayed in the Partner tab when no session is active.
struct FriendsListView: View {
    let viewModel: FriendsViewModel
    @Binding var pendingFriendRequestID: String?
    let onStartSession: (FriendProfile) -> Void
    let onGenerateCode: () -> Void
    let onEnterCode: () -> Void
    let onShowUsernameSetup: () -> Void

    @State private var isShowingAddFriend = false

    var body: some View {
        ScrollViewReader { proxy in
            List {
                if !viewModel.incomingRequests.isEmpty {
                    FriendRequestsSection(
                        viewModel: viewModel,
                        highlightedRequestID: viewModel.highlightedRequestID
                    )
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

                if let username = viewModel.currentUsername {
                    ShareProfileSection(
                        username: username,
                        senderName: viewModel.currentDisplayName
                    )
                }

                ShareInviteSection(senderName: viewModel.currentDisplayName)
            }
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
            .onChange(of: pendingFriendRequestID) { _, requestID in
                guard let requestID else { return }
                viewModel.highlightedRequestID = requestID
                pendingFriendRequestID = nil

                withAnimation {
                    proxy.scrollTo(requestID, anchor: .center)
                }

                // Clear highlight after a brief moment.
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    withAnimation {
                        viewModel.highlightedRequestID = nil
                    }
                }
            }
        }
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

// MARK: - Profile Share Sheet

private struct ProfileShareSheet: UIViewControllerRepresentable {
    let username: String
    let senderName: String

    private var appStoreURL: URL {
        URL(string: "https://apps.apple.com/app/pomo-duo/id6759349583")!
    }

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let itemSource = ProfileActivityItemSource(
            username: username,
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
        let renderer = ImageRenderer(content: ProfileShareIconView())
        renderer.scale = 3
        return renderer.uiImage ?? UIImage(systemName: "person.badge.plus")!
    }
}

private final class ProfileActivityItemSource: NSObject, UIActivityItemSource {
    let username: String
    let senderName: String
    let appStoreURL: URL
    let iconImage: UIImage

    private var deepLink: URL {
        URL(string: "pomoduo://add-friend/\(username)")!
    }

    init(
        username: String,
        senderName: String,
        appStoreURL: URL,
        iconImage: UIImage
    ) {
        self.username = username
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
        let name = senderName.isEmpty ? "Someone" : senderName
        return """
        \(name) wants to be your study friend on PomoDuo! \
        Add me: \(deepLink.absoluteString)

        Don't have PomoDuo yet? Download it here: \(appStoreURL.absoluteString)
        """
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
        metadata.originalURL = appStoreURL
        metadata.url = appStoreURL
        metadata.title = "Add Me on PomoDuo — @\(username)"
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
            Text("Share PomoDuo with friends who haven't downloaded it yet.")
        }
    }

    private var appStoreURL: URL {
        URL(string: "https://apps.apple.com/app/pomo-duo/id6759349583")
            ?? URL(string: "https://apple.com")!
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
        let controller = UIActivityViewController(
            activityItems: [itemSource],
            applicationActivities: nil
        )
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}

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
        let message = if senderName.isEmpty {
            "Join me on PomoDuo and let's crush our study goals together! 📚🔥\n\(appStoreURL.absoluteString)"
        } else {
            "\(senderName) wants to lock in with you on PomoDuo — a study timer built for accountability. Download it and let's crush our goals together! 📚🔥\n\(appStoreURL.absoluteString)"
        }
        return message
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        subjectForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        if senderName.isEmpty {
            "Lock In With Me on PomoDuo"
        } else {
            "Lock In With Me on PomoDuo"
        }
    }

    func activityViewControllerLinkMetadata(
        _ activityViewController: UIActivityViewController
    ) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.originalURL = appStoreURL
        metadata.url = appStoreURL
        metadata.title = if senderName.isEmpty {
            "Lock In With Me on PomoDuo"
        } else {
            "Lock In With Me on PomoDuo"
        }
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
