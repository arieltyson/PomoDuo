import Foundation
import OSLog
@preconcurrency import FirebaseAuth
@preconcurrency import FirebaseFirestore

/// Firestore-backed implementation of ``FriendService``.
@MainActor
final class FirebaseFriendService: FriendService {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.arieljtyson.PomoDuo",
        category: "FirebaseFriendService"
    )

    private enum Collections {
        static let users = "users"
        static let usernames = "usernames"
        static let friendRequests = "friendRequests"
        static let friendships = "friendships"
    }

    private enum Fields {
        static let uid = "uid"
        static let username = "username"
        static let usernameNormalized = "usernameNormalized"
        static let displayName = "displayName"
        static let createdAt = "createdAt"
        static let updatedAt = "updatedAt"
        static let fromUID = "fromUID"
        static let toUID = "toUID"
        static let fromDisplayName = "fromDisplayName"
        static let fromUsername = "fromUsername"
        static let status = "status"
        static let members = "members"
        static let memberDisplayNames = "memberDisplayNames"
        static let memberUsernames = "memberUsernames"
    }

    private let database: Firestore
    private let auth: Auth
    private let pushSender: PushNotificationSender?

    init(
        database: Firestore = Firestore.firestore(),
        auth: Auth = Auth.auth(),
        pushSender: PushNotificationSender? = nil
    ) {
        self.database = database
        self.auth = auth
        self.pushSender = pushSender
    }

    // MARK: - Username

    func claimUsername(_ username: String) async throws -> Bool {
        let user = try requireCurrentUser()
        let normalized = username.lowercased()
        let usernameRef = database.collection(Collections.usernames).document(normalized)
        let userRef = database.collection(Collections.users).document(user.uid)

        // Check-then-write: first verify availability, then batch create.
        // A small race window exists, but Firestore security rules can
        // enforce true uniqueness server-side if needed.
        do {
            let existing = try await usernameRef.getDocument()
            if existing.exists {
                return false
            }

            let batch = database.batch()
            batch.setData([
                Fields.uid: user.uid,
                Fields.createdAt: FieldValue.serverTimestamp(),
            ], forDocument: usernameRef)

            batch.setData([
                Fields.username: username,
                Fields.usernameNormalized: normalized,
                Fields.displayName: Self.displayName(for: user),
                Fields.updatedAt: FieldValue.serverTimestamp(),
            ], forDocument: userRef, merge: true)

            try await batch.commit()
            return true
        } catch {
            Self.logger.error("Username claim failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    func isUsernameAvailable(_ username: String) async throws -> Bool {
        let normalized = username.lowercased()
        let snapshot = try await database
            .collection(Collections.usernames)
            .document(normalized)
            .getDocument()
        return !snapshot.exists
    }

    func currentUsername() async throws -> String? {
        let user = try requireCurrentUser()
        let snapshot = try await database
            .collection(Collections.users)
            .document(user.uid)
            .getDocument()
        return snapshot.data()?[Fields.username] as? String
    }

    func searchByUsername(_ username: String) async throws -> UserSearchResult? {
        let user = try requireCurrentUser()
        let normalized = username.lowercased()

        let usernameSnapshot = try await database
            .collection(Collections.usernames)
            .document(normalized)
            .getDocument()

        guard
            let data = usernameSnapshot.data(),
            let targetUID = data[Fields.uid] as? String,
            targetUID != user.uid
        else {
            return nil
        }

        let userSnapshot = try await database
            .collection(Collections.users)
            .document(targetUID)
            .getDocument()

        guard let userData = userSnapshot.data() else {
            return nil
        }

        let displayName = (userData[Fields.displayName] as? String) ?? "Focus Friend"
        let storedUsername = (userData[Fields.username] as? String) ?? username

        return UserSearchResult(
            id: targetUID,
            displayName: displayName,
            username: storedUsername
        )
    }

    // MARK: - Friend Requests

    func sendFriendRequest(toUsername username: String) async throws {
        let user = try requireCurrentUser()
        let normalized = username.lowercased()

        let usernameSnapshot = try await database
            .collection(Collections.usernames)
            .document(normalized)
            .getDocument()

        guard
            let usernameData = usernameSnapshot.data(),
            let targetUID = usernameData[Fields.uid] as? String,
            targetUID != user.uid
        else {
            return
        }

        // Check if friendship or pending request already exists.
        let friendshipID = Self.friendshipID(user.uid, targetUID)
        let existingFriendship = try await database
            .collection(Collections.friendships)
            .document(friendshipID)
            .getDocument()

        if existingFriendship.exists {
            return
        }

        let existingRequest = try await database
            .collection(Collections.friendRequests)
            .whereField(Fields.fromUID, isEqualTo: user.uid)
            .whereField(Fields.toUID, isEqualTo: targetUID)
            .whereField(Fields.status, isEqualTo: FriendRequestStatus.pending.rawValue)
            .limit(to: 1)
            .getDocuments()

        if !existingRequest.documents.isEmpty {
            return
        }

        let senderUsername = try await currentUsername() ?? ""
        let senderDisplayName = Self.displayName(for: user)

        let requestData: [String: Any] = [
            Fields.fromUID: user.uid,
            Fields.toUID: targetUID,
            Fields.fromDisplayName: senderDisplayName,
            Fields.fromUsername: senderUsername,
            Fields.status: FriendRequestStatus.pending.rawValue,
            Fields.createdAt: FieldValue.serverTimestamp(),
            Fields.updatedAt: FieldValue.serverTimestamp(),
        ]

        try await database
            .collection(Collections.friendRequests)
            .addDocument(data: requestData)

        try? await pushSender?.sendPush(
            to: targetUID,
            title: "Friend Request",
            body: "\(senderDisplayName) wants to be study friends!",
            category: .friendRequest,
            payload: ["action": "friend_request"]
        )
    }

    func acceptFriendRequest(_ requestID: String) async throws {
        let user = try requireCurrentUser()
        let requestRef = database.collection(Collections.friendRequests).document(requestID)
        let requestSnapshot = try await requestRef.getDocument()

        guard
            let data = requestSnapshot.data(),
            let fromUID = data[Fields.fromUID] as? String,
            let toUID = data[Fields.toUID] as? String,
            toUID == user.uid
        else {
            return
        }

        // Update request status.
        try await requestRef.updateData([
            Fields.status: FriendRequestStatus.accepted.rawValue,
            Fields.updatedAt: FieldValue.serverTimestamp(),
        ])

        // Fetch both user profiles for the friendship doc.
        let fromUserSnapshot = try await database
            .collection(Collections.users)
            .document(fromUID)
            .getDocument()

        let fromDisplayName = (fromUserSnapshot.data()?[Fields.displayName] as? String)
            ?? "Focus Friend"
        let fromUsername = (fromUserSnapshot.data()?[Fields.username] as? String) ?? ""

        let toDisplayName = Self.displayName(for: user)
        let toUsername = try await currentUsername() ?? ""

        let memberIDs = [fromUID, toUID].sorted()
        let friendshipID = Self.friendshipID(fromUID, toUID)

        let friendshipData: [String: Any] = [
            Fields.members: memberIDs,
            Fields.memberDisplayNames: [
                fromUID: fromDisplayName,
                toUID: toDisplayName,
            ],
            Fields.memberUsernames: [
                fromUID: fromUsername,
                toUID: toUsername,
            ],
            Fields.createdAt: FieldValue.serverTimestamp(),
        ]

        try await database
            .collection(Collections.friendships)
            .document(friendshipID)
            .setData(friendshipData)

        try? await pushSender?.sendPush(
            to: fromUID,
            title: "Friend Request Accepted",
            body: "\(toDisplayName) accepted your friend request!",
            category: .friendRequestAccepted,
            payload: ["action": "friend_accepted"]
        )
    }

    func declineFriendRequest(_ requestID: String) async throws {
        try await database
            .collection(Collections.friendRequests)
            .document(requestID)
            .updateData([
                Fields.status: FriendRequestStatus.declined.rawValue,
                Fields.updatedAt: FieldValue.serverTimestamp(),
            ])
    }

    // MARK: - Friendships

    func removeFriend(_ friendUID: String) async throws {
        let user = try requireCurrentUser()
        let friendshipID = Self.friendshipID(user.uid, friendUID)
        try await database
            .collection(Collections.friendships)
            .document(friendshipID)
            .delete()
    }

    func friends() async throws -> [FriendProfile] {
        let user = try requireCurrentUser()
        let snapshot = try await database
            .collection(Collections.friendships)
            .whereField(Fields.members, arrayContains: user.uid)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            Self.makeFriendProfile(from: doc.data(), currentUserID: user.uid)
        }
    }

    func friendsStream() -> AsyncStream<[FriendProfile]> {
        guard let currentUserID = auth.currentUser?.uid else {
            return AsyncStream { $0.finish() }
        }

        let query = database
            .collection(Collections.friendships)
            .whereField(Fields.members, arrayContains: currentUserID)

        return AsyncStream { continuation in
            let listener = query.addSnapshotListener { snapshot, error in
                if error != nil {
                    continuation.yield([])
                    return
                }

                let friends = (snapshot?.documents ?? []).compactMap { doc in
                    Self.makeFriendProfile(from: doc.data(), currentUserID: currentUserID)
                }
                continuation.yield(friends)
            }

            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }

    func incomingRequestsStream() -> AsyncStream<[FriendRequest]> {
        guard let currentUserID = auth.currentUser?.uid else {
            return AsyncStream { $0.finish() }
        }

        let query = database
            .collection(Collections.friendRequests)
            .whereField(Fields.toUID, isEqualTo: currentUserID)
            .whereField(Fields.status, isEqualTo: FriendRequestStatus.pending.rawValue)

        return AsyncStream { continuation in
            let listener = query.addSnapshotListener { snapshot, error in
                if error != nil {
                    continuation.yield([])
                    return
                }

                let requests = (snapshot?.documents ?? []).compactMap { doc -> FriendRequest? in
                    let data = doc.data()
                    guard
                        let fromUID = data[Fields.fromUID] as? String,
                        let toUID = data[Fields.toUID] as? String,
                        let statusRaw = data[Fields.status] as? String,
                        let status = FriendRequestStatus(rawValue: statusRaw)
                    else {
                        return nil
                    }

                    let createdAt = (data[Fields.createdAt] as? Timestamp)?.dateValue() ?? .now

                    return FriendRequest(
                        id: doc.documentID,
                        fromUID: fromUID,
                        fromDisplayName: (data[Fields.fromDisplayName] as? String) ?? "Focus Friend",
                        fromUsername: (data[Fields.fromUsername] as? String) ?? "",
                        toUID: toUID,
                        status: status,
                        createdAt: createdAt
                    )
                }
                continuation.yield(requests)
            }

            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }

    // MARK: - Helpers

    private func requireCurrentUser() throws -> User {
        guard let user = auth.currentUser else {
            throw AuthServiceError.notAuthenticated
        }
        return user
    }

    private static func friendshipID(_ uid1: String, _ uid2: String) -> String {
        [uid1, uid2].sorted().joined(separator: "_")
    }

    private static func displayName(for user: User) -> String {
        if let displayName = user.displayName,
            !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            return displayName
        }

        if let email = user.email,
            let name = email.split(separator: "@").first,
            !name.isEmpty
        {
            return String(name)
        }

        return "Focus Friend"
    }

    private static func makeFriendProfile(
        from data: [String: Any],
        currentUserID: String
    ) -> FriendProfile? {
        guard
            let memberIDs = data[Fields.members] as? [String],
            memberIDs.contains(currentUserID),
            let friendID = memberIDs.first(where: { $0 != currentUserID })
        else {
            return nil
        }

        let displayNames = data[Fields.memberDisplayNames] as? [String: String]
        let usernames = data[Fields.memberUsernames] as? [String: String]
        let createdAt = (data[Fields.createdAt] as? Timestamp)?.dateValue() ?? .now

        return FriendProfile(
            id: friendID,
            displayName: displayNames?[friendID] ?? "Focus Friend",
            username: usernames?[friendID] ?? "",
            friendsSince: createdAt
        )
    }
}
