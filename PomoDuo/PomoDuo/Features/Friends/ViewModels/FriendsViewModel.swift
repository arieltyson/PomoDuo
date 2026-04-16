import Foundation
import OSLog
import Observation

/// Observable state and intents for the friends list and friend requests.
@MainActor
@Observable
final class FriendsViewModel {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.arieljtyson.PomoDuo",
        category: "FriendsViewModel"
    )
    /// Current friends list, updated in real-time.
    private(set) var friends: [FriendProfile] = []

    /// Pending incoming friend requests.
    private(set) var incomingRequests: [FriendRequest] = []

    /// Username search query.
    var searchQuery = ""

    /// Result of the most recent username search.
    private(set) var searchResult: UserSearchResult?

    /// Whether a search is in progress.
    private(set) var isSearching = false

    /// Whether a friend request is being sent.
    private(set) var isSendingRequest = false

    /// Whether the search found no results.
    private(set) var searchFoundNoResults = false

    /// User-facing error message.
    private(set) var error: String?

    /// Friend request ID to highlight, set via deeplink or notification.
    var highlightedRequestID: String?

    /// Current user's username, if set.
    private(set) var currentUsername: String?

    /// Whether username setup is needed.
    var needsUsernameSetup: Bool {
        currentUsername == nil
    }

    /// Display name of the current user, for personalizing invites.
    private(set) var currentDisplayName = ""

    // MARK: - Username Setup

    /// Username input for the setup flow.
    var usernameInput = ""

    /// Real-time validation result for the username input.
    private(set) var usernameValidation = UsernameValidationResult.empty

    /// Whether the entered username is available on the server.
    private(set) var isUsernameAvailable: Bool?

    /// Whether an availability check is in progress.
    private(set) var isCheckingAvailability = false

    /// Whether username is being claimed.
    private(set) var isClaimingUsername = false

    private let friendService: any FriendService
    private var friendsTask: Task<Void, Never>?
    private var requestsTask: Task<Void, Never>?
    private var usernameTask: Task<Void, Never>?
    private var availabilityTask: Task<Void, Never>?

    init(friendService: any FriendService) {
        self.friendService = friendService
    }

    // MARK: - Lifecycle

    func startObserving(displayName: String = "") {
        currentDisplayName = displayName

        friendsTask?.cancel()
        friendsTask = Task { [weak self] in
            guard let self else { return }
            for await friends in friendService.friendsStream() {
                guard !Task.isCancelled else { return }
                self.friends = friends.sorted { $0.displayName < $1.displayName }
            }
        }

        requestsTask?.cancel()
        requestsTask = Task { [weak self] in
            guard let self else { return }
            for await requests in friendService.incomingRequestsStream() {
                guard !Task.isCancelled else { return }
                self.incomingRequests = requests.sorted { $0.createdAt > $1.createdAt }
            }
        }

        usernameTask?.cancel()
        usernameTask = Task { [weak self] in
            guard let self else { return }
            let username = try? await friendService.currentUsername()
            guard !Task.isCancelled else { return }
            currentUsername = username
        }
    }

    func stopObserving() {
        friendsTask?.cancel()
        friendsTask = nil
        requestsTask?.cancel()
        requestsTask = nil
        usernameTask?.cancel()
        usernameTask = nil
        friends = []
        incomingRequests = []
        currentUsername = nil
    }

    /// Refreshes the display name shown on invite/share surfaces without
    /// tearing down the friends, requests, and username streams.
    ///
    /// The tab-level `.task(id: authManager.isSignedIn)` only re-runs on
    /// identity transitions, so same-identity profile updates (e.g.
    /// `AuthManager.updateDisplayName`) would otherwise leave
    /// ``currentDisplayName`` stale in Partner share/invite UI. Pushing
    /// the new name through this method keeps the observer pipeline stable
    /// while still propagating the update.
    func updateDisplayName(_ newName: String) {
        currentDisplayName = newName
    }

    #if DEBUG
    /// Awaits completion of the currently in-flight username fetch, if any.
    ///
    /// Used by lifecycle tests to synchronize deterministically instead of
    /// sleeping for an arbitrary duration and hoping the async work finishes
    /// in time under full-suite main-actor contention.
    func waitForCurrentUsernameFetchForTests() async {
        await usernameTask?.value
    }
    #endif

    // MARK: - Username

    func validateUsername() {
        let input = usernameInput.trimmingCharacters(in: .whitespacesAndNewlines)

        if input.isEmpty {
            usernameValidation = .empty
            isUsernameAvailable = nil
            return
        }

        if input.count < UsernameValidationResult.minLength {
            usernameValidation = .tooShort
            isUsernameAvailable = nil
            return
        }

        if input.count > UsernameValidationResult.maxLength {
            usernameValidation = .tooLong
            isUsernameAvailable = nil
            return
        }

        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        if input.unicodeScalars.contains(where: { !allowedCharacters.contains($0) }) {
            usernameValidation = .invalidCharacters
            isUsernameAvailable = nil
            return
        }

        usernameValidation = .valid
        checkAvailability(for: input)
    }

    private func checkAvailability(for username: String) {
        availabilityTask?.cancel()
        isCheckingAvailability = true
        isUsernameAvailable = nil

        availabilityTask = Task { [weak self] in
            // Debounce.
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled, let self else { return }

            let available = try? await friendService.isUsernameAvailable(username)
            guard !Task.isCancelled else { return }

            isUsernameAvailable = available
            isCheckingAvailability = false
        }
    }

    func claimUsername() async {
        let username = usernameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard usernameValidation == .valid, isUsernameAvailable == true else { return }

        isClaimingUsername = true
        let claimed = try? await friendService.claimUsername(username)
        isClaimingUsername = false

        if claimed == true {
            currentUsername = username
            usernameInput = ""
        } else {
            error = "Could not claim that username. It may have just been taken."
            isUsernameAvailable = false
        }
    }

    // MARK: - Search

    func searchForUser() async {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return }

        isSearching = true
        searchFoundNoResults = false
        searchResult = nil
        error = nil

        do {
            let result = try await friendService.searchByUsername(query)
            searchResult = result
            searchFoundNoResults = result == nil
        } catch {
            self.error = "Search failed. Please try again."
        }

        isSearching = false
    }

    func sendFriendRequest() async {
        guard let result = searchResult else { return }

        isSendingRequest = true
        error = nil

        do {
            try await friendService.sendFriendRequest(toUsername: result.username)
            searchResult = nil
            searchQuery = ""
            searchFoundNoResults = false
        } catch let serviceError as FriendServiceError {
            self.error = serviceError.errorDescription
        } catch {
            Self.logger.error("Failed to send friend request: \(error)")
            self.error = "Could not send friend request. Please try again."
        }

        isSendingRequest = false
    }

    // MARK: - Request Actions

    func acceptRequest(_ request: FriendRequest) async {
        do {
            try await friendService.acceptFriendRequest(request.id)
        } catch {
            self.error = "Could not accept request. Please try again."
        }
    }

    func declineRequest(_ request: FriendRequest) async {
        do {
            try await friendService.declineFriendRequest(request.id)
        } catch {
            self.error = "Could not decline request. Please try again."
        }
    }

    // MARK: - Friend Actions

    func removeFriend(_ friend: FriendProfile) async {
        do {
            try await friendService.removeFriend(friend.id)
        } catch {
            self.error = "Could not remove friend. Please try again."
        }
    }

    func dismissError() {
        error = nil
    }
}
