import SwiftUI

/// Root view for the Partner tab.
///
/// Integrates the friends system for persistent connections and the
/// legacy code-based pairing for one-time sessions. When a paired
/// session is active, switches to ``ActivePairedSessionView``. If the
/// current user received a session request, shows
/// ``IncomingSessionRequestView`` instead.
struct PartnerView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(SessionManager.self) private var sessionManager

    @State private var pairingViewModel: PairingViewModel
    @State private var friendsViewModel: FriendsViewModel
    @State private var sessionViewModel: PartnerSessionViewModel?
    @State private var isShowingCodeSheet = false
    @State private var isShowingUsernameSetup = false

    /// The partner profile used for the active session. Built from
    /// whichever source (friend or legacy pairing) initiated the session.
    @State private var activePartner: PartnerProfile?

    init(
        pairingService: any PairingService = MockPairingService(),
        friendService: any FriendService
    ) {
        _pairingViewModel = State(
            initialValue: PairingViewModel(pairingService: pairingService)
        )
        _friendsViewModel = State(
            initialValue: FriendsViewModel(friendService: friendService)
        )
    }

    var body: some View {
        Group {
            if authManager.isSignedIn {
                if let sessionViewModel {
                    SignedInPartnerContent(
                        pairingViewModel: pairingViewModel,
                        friendsViewModel: friendsViewModel,
                        sessionViewModel: sessionViewModel,
                        activePartner: $activePartner,
                        isShowingCodeSheet: $isShowingCodeSheet,
                        isShowingUsernameSetup: $isShowingUsernameSetup
                    )
                } else {
                    ProgressView("Preparing…")
                }
            } else {
                UnauthenticatedPartnerView(authManager: authManager)
            }
        }
        .navigationTitle("Partner")
        .sheet(isPresented: $isShowingCodeSheet) {
            CodeEntrySheet(viewModel: pairingViewModel)
        }
        .sheet(isPresented: $isShowingUsernameSetup) {
            NavigationStack {
                UsernameSetupView(
                    viewModel: friendsViewModel,
                    onComplete: { isShowingUsernameSetup = false }
                )
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Later") { isShowingUsernameSetup = false }
                    }
                }
            }
        }
        .task {
            if sessionViewModel == nil {
                sessionViewModel = PartnerSessionViewModel(
                    sessionManager: sessionManager
                )
            }
        }
        .task(id: authManager.isSignedIn) {
            if authManager.isSignedIn {
                await pairingViewModel.checkExistingPairing()
                friendsViewModel.startObserving()
            } else {
                isShowingCodeSheet = false
                pairingViewModel.resetForSignedOut()
                friendsViewModel.stopObserving()
                sessionViewModel?.reset()
                activePartner = nil
            }
        }
    }
}

private struct SignedInPartnerContent: View {
    let pairingViewModel: PairingViewModel
    let friendsViewModel: FriendsViewModel
    let sessionViewModel: PartnerSessionViewModel
    @Binding var activePartner: PartnerProfile?
    @Binding var isShowingCodeSheet: Bool
    @Binding var isShowingUsernameSetup: Bool

    var body: some View {
        if let session = sessionViewModel.activeSession,
            session.state != .idle
        {
            // Resolve the partner profile from friends or legacy pairing.
            let partner = resolvePartner(for: session)

            if sessionViewModel.isIncomingRequest {
                IncomingSessionRequestView(
                    partner: partner,
                    viewModel: sessionViewModel
                )
            } else {
                ActivePairedSessionView(
                    session: session,
                    partner: partner,
                    viewModel: sessionViewModel
                )
            }
        } else {
            FriendsAndPairingContent(
                pairingViewModel: pairingViewModel,
                friendsViewModel: friendsViewModel,
                sessionViewModel: sessionViewModel,
                activePartner: $activePartner,
                isShowingCodeSheet: $isShowingCodeSheet,
                isShowingUsernameSetup: $isShowingUsernameSetup
            )
        }
    }

    /// Resolves a PartnerProfile for the active session by checking
    /// the friends list first, then falling back to legacy pairing.
    private func resolvePartner(for session: StudySession) -> PartnerProfile {
        if let cached = activePartner {
            return cached
        }

        let userID = sessionViewModel.sessionManager.currentUserID ?? ""
        let partnerID = session.partnerID(for: userID) ?? ""

        // Check friends list.
        if let friend = friendsViewModel.friends.first(where: { $0.id == partnerID }) {
            return PartnerProfile(
                id: friend.id,
                displayName: friend.displayName,
                pairedAt: friend.friendsSince
            )
        }

        // Fall back to legacy pairing state.
        if case .paired(let partner) = pairingViewModel.pairingState {
            return partner
        }

        return PartnerProfile(
            id: partnerID,
            displayName: "Focus Friend",
            pairedAt: .now
        )
    }
}

/// Combined view showing both the friends list and legacy pairing flow.
private struct FriendsAndPairingContent: View {
    let pairingViewModel: PairingViewModel
    let friendsViewModel: FriendsViewModel
    let sessionViewModel: PartnerSessionViewModel
    @Binding var activePartner: PartnerProfile?
    @Binding var isShowingCodeSheet: Bool
    @Binding var isShowingUsernameSetup: Bool

    @Environment(SessionManager.self) private var sessionManager

    var body: some View {
        VStack(spacing: 0) {
            ConnectionStatusBanner()

            // Username setup prompt.
            if friendsViewModel.needsUsernameSetup {
                UsernamePromptBanner(
                    onSetup: { isShowingUsernameSetup = true }
                )
            }

            // Active pairing state takes precedence.
            switch pairingViewModel.pairingState {
            case .waitingForPartner(let code):
                WaitingForPartnerView(
                    code: code,
                    onCancel: { pairingViewModel.cancelWaiting() }
                )
            case .joining:
                JoiningView()
            case .error(let message):
                PairingErrorView(
                    message: message,
                    onRetry: { pairingViewModel.dismissError() }
                )
            case .paired(let partner):
                PairedPartnerView(
                    partner: partner,
                    sessionViewModel: sessionViewModel,
                    onUnpair: {
                        Task { await pairingViewModel.unpair() }
                    }
                )
            case .unpaired:
                FriendsListView(
                    viewModel: friendsViewModel,
                    onStartSession: { friend in
                        startSessionWithFriend(friend)
                    },
                    onGenerateCode: {
                        Task { await pairingViewModel.generateCode() }
                    },
                    onEnterCode: {
                        isShowingCodeSheet = true
                    },
                    onShowUsernameSetup: {
                        isShowingUsernameSetup = true
                    }
                )
            }
        }
    }

    private func startSessionWithFriend(_ friend: FriendProfile) {
        let partner = PartnerProfile(
            id: friend.id,
            displayName: friend.displayName,
            pairedAt: friend.friendsSince
        )
        activePartner = partner

        Task {
            await sessionViewModel.startSession(with: partner)
        }
    }
}

private struct UsernamePromptBanner: View {
    let onSetup: () -> Void

    var body: some View {
        Button {
            onSetup()
        } label: {
            HStack {
                Image(systemName: "at")
                    .font(.title3)
                    .foregroundStyle(AppColors.lavender)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Set Up Your Username")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    Text("Friends can find you by username.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(
                AppColors.paleViolet.opacity(0.14),
                in: .rect(cornerRadius: 12)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
        .padding(.top, 8)
        .accessibilityLabel("Set up username so friends can find you")
    }
}

private struct UnauthenticatedPartnerView: View {
    let authManager: AuthManager

    var body: some View {
        ContentUnavailableView {
            Label(
                "Sign In Required",
                systemImage: "person.crop.circle.badge.exclamationmark"
            )
        } description: {
            Text("Sign in to connect with study partners.")
        } actions: {
            Button(
                "Sign In as Guest",
                systemImage: "person.crop.circle.badge.plus"
            ) {
                Task {
                    await authManager.signInAnonymously()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColors.lavender)
            .disabled(authManager.isLoading)
        }
    }
}
