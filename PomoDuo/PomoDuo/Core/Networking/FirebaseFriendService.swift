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
        static let dailyFocusMinutes = "dailyFocusMinutes"
        static let weeklyFocusMinutes = "weeklyFocusMinutes"
        static let totalFocusMinutes = "totalFocusMinutes"
        static let currentStreak = "currentStreak"
        static let weekStartDate = "weekStartDate"
        static let lastSessionDate = "lastSessionDate"
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
            let targetUID = usernameData[Fields.uid] as? String
        else {
            throw FriendServiceError.userNotFound
        }

        guard targetUID != user.uid else {
            throw FriendServiceError.cannotAddSelf
        }

        // Check if friendship already exists.
        let friendshipID = Self.friendshipID(user.uid, targetUID)
        let existingFriendship = try await database
            .collection(Collections.friendships)
            .document(friendshipID)
            .getDocument()

        if existingFriendship.exists {
            throw FriendServiceError.alreadyFriends
        }

        // Check for existing pending request using individual queries
        // to avoid requiring a composite index.
        let outgoingRequests = try await database
            .collection(Collections.friendRequests)
            .whereField(Fields.fromUID, isEqualTo: user.uid)
            .whereField(Fields.toUID, isEqualTo: targetUID)
            .getDocuments()

        let hasPendingOutgoing = outgoingRequests.documents.contains { doc in
            (doc.data()[Fields.status] as? String) == FriendRequestStatus.pending.rawValue
        }

        if hasPendingOutgoing {
            throw FriendServiceError.requestAlreadySent
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

        let requestRef = try await database
            .collection(Collections.friendRequests)
            .addDocument(data: requestData)

        Self.logger.info("Friend request sent to \(targetUID, privacy: .private)")

        try? await pushSender?.sendPush(
            to: targetUID,
            title: "Friend Request",
            body: "\(senderDisplayName) wants to be study friends!",
            category: .friendRequest,
            payload: [
                "action": "friend_request",
                "friendRequestID": requestRef.documentID,
            ]
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

    // MARK: - Leaderboard

    func reportFocusSession(minutes: Int) async throws {
        let user = try requireCurrentUser()
        let userRef = database.collection(Collections.users).document(user.uid)

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let weekStart = Self.mondayOfWeek(containing: today, calendar: calendar)

        // Read current stats to decide whether the weekly counter needs resetting.
        let snapshot = try await userRef.getDocument()
        let data = snapshot.data() ?? [:]

        let storedWeekStart = (data[Fields.weekStartDate] as? Timestamp)?.dateValue()
        let storedLastSession = (data[Fields.lastSessionDate] as? Timestamp)?.dateValue()
        let storedStreak = (data[Fields.currentStreak] as? Int) ?? 0

        // Reset daily minutes if the stored session date is a different day.
        let dailyMinutes: Int
        if let storedLastSession, calendar.isDate(storedLastSession, inSameDayAs: today) {
            dailyMinutes = ((data[Fields.dailyFocusMinutes] as? Int) ?? 0) + minutes
        } else {
            dailyMinutes = minutes
        }

        // Reset weekly minutes if the stored week is different from the current week.
        let weeklyMinutes: Int
        if let storedWeekStart, calendar.isDate(storedWeekStart, inSameDayAs: weekStart) {
            weeklyMinutes = ((data[Fields.weeklyFocusMinutes] as? Int) ?? 0) + minutes
        } else {
            weeklyMinutes = minutes
        }

        // Streak: increment if this is a new day, maintain if same day, reset if gap > 1 day.
        let newStreak: Int
        if let storedLastSession {
            let lastDay = calendar.startOfDay(for: storedLastSession)
            if calendar.isDate(lastDay, inSameDayAs: today) {
                newStreak = storedStreak
            } else if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
                calendar.isDate(lastDay, inSameDayAs: yesterday)
            {
                newStreak = storedStreak + 1
            } else {
                newStreak = 1
            }
        } else {
            newStreak = 1
        }

        try await userRef.setData([
            Fields.dailyFocusMinutes: dailyMinutes,
            Fields.weeklyFocusMinutes: weeklyMinutes,
            Fields.totalFocusMinutes: FieldValue.increment(Int64(minutes)),
            Fields.currentStreak: newStreak,
            Fields.weekStartDate: Timestamp(date: weekStart),
            Fields.lastSessionDate: Timestamp(date: today),
            Fields.updatedAt: FieldValue.serverTimestamp(),
        ], merge: true)
    }

    func leaderboardEntries() async throws -> [LeaderboardEntry] {
        let user = try requireCurrentUser()
        let currentUsername = try await currentUsername() ?? ""

        // Fetch current user's stats.
        let userDoc = try await database
            .collection(Collections.users)
            .document(user.uid)
            .getDocument()

        let userData = userDoc.data() ?? [:]
        let calendar = Calendar.current
        let weekStart = Self.mondayOfWeek(
            containing: calendar.startOfDay(for: .now),
            calendar: calendar
        )

        var entries = [
            Self.makeLeaderboardEntry(
                uid: user.uid,
                data: userData,
                weekStart: weekStart,
                calendar: calendar,
                fallbackDisplayName: Self.displayName(for: user),
                fallbackUsername: currentUsername,
                isCurrentUser: true
            ),
        ]

        // Fetch all friends.
        let friendships = try await database
            .collection(Collections.friendships)
            .whereField(Fields.members, arrayContains: user.uid)
            .getDocuments()

        let friendIDs = friendships.documents.compactMap { doc -> String? in
            let members = doc.data()[Fields.members] as? [String]
            return members?.first(where: { $0 != user.uid })
        }

        // Fetch each friend's stats. Batching in groups of 10 for efficiency.
        for batch in stride(from: 0, to: friendIDs.count, by: 10) {
            let batchIDs = Array(friendIDs[batch..<min(batch + 10, friendIDs.count)])

            let friendDocs = try await database
                .collection(Collections.users)
                .whereField(FieldPath.documentID(), in: batchIDs)
                .getDocuments()

            for doc in friendDocs.documents {
                let friendData = doc.data()
                entries.append(
                    Self.makeLeaderboardEntry(
                        uid: doc.documentID,
                        data: friendData,
                        weekStart: weekStart,
                        calendar: calendar,
                        fallbackDisplayName: "Focus Friend",
                        fallbackUsername: "",
                        isCurrentUser: false
                    )
                )
            }
        }

        return entries
    }

    private static func makeLeaderboardEntry(
        uid: String,
        data: [String: Any],
        weekStart: Date,
        calendar: Calendar,
        fallbackDisplayName: String,
        fallbackUsername: String,
        isCurrentUser: Bool
    ) -> LeaderboardEntry {
        let storedWeekStart = (data[Fields.weekStartDate] as? Timestamp)?.dateValue()
        let storedLastSession = (data[Fields.lastSessionDate] as? Timestamp)?.dateValue()

        let isCurrentWeek: Bool
        if let storedWeekStart {
            isCurrentWeek = calendar.isDate(storedWeekStart, inSameDayAs: weekStart)
        } else {
            isCurrentWeek = false
        }

        let isToday: Bool
        if let storedLastSession {
            isToday = calendar.isDateInToday(storedLastSession)
        } else {
            isToday = false
        }

        return LeaderboardEntry(
            id: uid,
            displayName: (data[Fields.displayName] as? String) ?? fallbackDisplayName,
            username: (data[Fields.username] as? String) ?? fallbackUsername,
            dailyFocusMinutes: isToday
                ? ((data[Fields.dailyFocusMinutes] as? Int) ?? 0)
                : 0,
            weeklyFocusMinutes: isCurrentWeek
                ? ((data[Fields.weeklyFocusMinutes] as? Int) ?? 0)
                : 0,
            totalFocusMinutes: (data[Fields.totalFocusMinutes] as? Int) ?? 0,
            currentStreak: (data[Fields.currentStreak] as? Int) ?? 0,
            isCurrentUser: isCurrentUser
        )
    }

    /// Returns Monday 00:00 of the week containing the given date.
    private static func mondayOfWeek(
        containing date: Date,
        calendar: Calendar
    ) -> Date {
        var cal = calendar
        cal.firstWeekday = 2  // Monday
        let components = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return cal.date(from: components) ?? date
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
