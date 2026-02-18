import Foundation
@preconcurrency import FirebaseAuth
@preconcurrency import FirebaseFirestore

/// Firestore-backed implementation of ``PairingService``.
@MainActor
final class FirebasePairingService: PairingService {
    private enum Collections {
        static let pairingCodes = "pairingCodes"
        static let partnerships = "partnerships"
        static let users = "users"
    }

    private enum Fields {
        static let ownerID = "ownerID"
        static let ownerDisplayName = "ownerDisplayName"
        static let createdAt = "createdAt"
        static let members = "members"
        static let memberDisplayNames = "memberDisplayNames"
        static let pairedAt = "pairedAt"
        static let sourceCode = "sourceCode"
        static let displayName = "displayName"
        static let updatedAt = "updatedAt"
    }

    private let database: Firestore
    private let auth: Auth

    init(database: Firestore = Firestore.firestore(), auth: Auth = Auth.auth()) {
        self.database = database
        self.auth = auth
    }

    func publishCode(_ code: PairCode) async throws -> Bool {
        let user = try requireCurrentUser()
        let displayName = Self.displayName(for: user)

        try await cleanupPublishedCodes(for: user.uid, keeping: code.value)

        let data: [String: Any] = [
            Fields.ownerID: user.uid,
            Fields.ownerDisplayName: displayName,
            Fields.createdAt: FieldValue.serverTimestamp(),
        ]

        try await pairingCodeReference(for: code).setData(data)
        try await upsertCurrentUserDocument(userID: user.uid, displayName: displayName)

        return true
    }

    func joinWithCode(_ code: PairCode) async throws -> PartnerProfile? {
        let joiningUser = try requireCurrentUser()
        let pairingCodeReference = pairingCodeReference(for: code)
        let pairingCodeSnapshot = try await pairingCodeReference.getDocument()

        guard
            let codeData = pairingCodeSnapshot.data(),
            let ownerID = codeData[Fields.ownerID] as? String,
            ownerID != joiningUser.uid
        else {
            return nil
        }

        let ownerDisplayName =
            (codeData[Fields.ownerDisplayName] as? String) ?? "Focus Friend"
        let joiningDisplayName = Self.displayName(for: joiningUser)
        let memberIDs = [ownerID, joiningUser.uid].sorted()

        let partnershipData: [String: Any] = [
            Fields.members: memberIDs,
            Fields.memberDisplayNames: [
                ownerID: ownerDisplayName,
                joiningUser.uid: joiningDisplayName,
            ],
            Fields.pairedAt: FieldValue.serverTimestamp(),
            Fields.sourceCode: code.value,
        ]

        let partnershipReference = partnershipReference(for: code)
        try await partnershipReference.setData(partnershipData)
        try await pairingCodeReference.delete()
        try await upsertCurrentUserDocument(
            userID: joiningUser.uid,
            displayName: joiningDisplayName
        )

        let partnershipSnapshot = try await partnershipReference.getDocument()
        let pairedAt = (partnershipSnapshot.data()?[Fields.pairedAt] as? Timestamp)?
            .dateValue() ?? .now

        return PartnerProfile(
            id: ownerID,
            displayName: ownerDisplayName,
            pairedAt: pairedAt
        )
    }

    func waitForPartner(code: PairCode) -> AsyncStream<PartnerProfile> {
        guard let currentUserID = auth.currentUser?.uid else {
            return AsyncStream { continuation in
                continuation.finish()
            }
        }

        let partnershipReference = partnershipReference(for: code)

        return AsyncStream { continuation in
            let listener = partnershipReference.addSnapshotListener { snapshot, error in
                if error != nil {
                    continuation.finish()
                    return
                }

                guard
                    let data = snapshot?.data(),
                    let partner = Self.makePartnerProfile(
                        from: data,
                        currentUserID: currentUserID
                    )
                else {
                    return
                }

                continuation.yield(partner)
                continuation.finish()
            }

            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }

    func unpair() async throws {
        guard let currentUserID = auth.currentUser?.uid else {
            return
        }

        try await deleteDocuments(
            matching: database.collection(Collections.partnerships)
                .whereField(Fields.members, arrayContains: currentUserID)
        )
        try await deleteDocuments(
            matching: database.collection(Collections.pairingCodes)
                .whereField(Fields.ownerID, isEqualTo: currentUserID)
        )
    }

    func currentPartner() async throws -> PartnerProfile? {
        guard let currentUserID = auth.currentUser?.uid else {
            return nil
        }

        let snapshot = try await database.collection(Collections.partnerships)
            .whereField(Fields.members, arrayContains: currentUserID)
            .limit(to: 1)
            .getDocuments()

        guard let data = snapshot.documents.first?.data() else {
            return nil
        }

        return Self.makePartnerProfile(from: data, currentUserID: currentUserID)
    }

    private func pairingCodeReference(for code: PairCode) -> DocumentReference {
        database.collection(Collections.pairingCodes).document(code.value)
    }

    private func partnershipReference(for code: PairCode) -> DocumentReference {
        database.collection(Collections.partnerships).document(code.value)
    }

    private func requireCurrentUser() throws -> User {
        guard let user = auth.currentUser else {
            throw AuthServiceError.notAuthenticated
        }

        return user
    }

    private func deleteDocuments(matching query: Query) async throws {
        let snapshot = try await query.getDocuments()
        guard !snapshot.documents.isEmpty else {
            return
        }

        let batch = database.batch()
        for document in snapshot.documents {
            batch.deleteDocument(document.reference)
        }
        try await batch.commit()
    }

    private func cleanupPublishedCodes(for userID: String, keeping code: String) async throws {
        let snapshot = try await database.collection(Collections.pairingCodes)
            .whereField(Fields.ownerID, isEqualTo: userID)
            .getDocuments()

        let staleDocuments = snapshot.documents.filter { $0.documentID != code }
        guard !staleDocuments.isEmpty else {
            return
        }

        let batch = database.batch()
        for document in staleDocuments {
            batch.deleteDocument(document.reference)
        }
        try await batch.commit()
    }

    private func upsertCurrentUserDocument(userID: String, displayName: String) async throws {
        let data: [String: Any] = [
            Fields.displayName: displayName,
            Fields.updatedAt: FieldValue.serverTimestamp(),
        ]

        try await database.collection(Collections.users).document(userID).setData(data, merge: true)
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

    private static func makePartnerProfile(
        from data: [String: Any],
        currentUserID: String
    ) -> PartnerProfile? {
        guard
            let memberIDs = data[Fields.members] as? [String],
            memberIDs.contains(currentUserID),
            let partnerID = memberIDs.first(where: { $0 != currentUserID })
        else {
            return nil
        }

        let displayNames = data[Fields.memberDisplayNames] as? [String: String]
        let partnerDisplayName = displayNames?[partnerID] ?? "Focus Friend"
        let pairedAt = (data[Fields.pairedAt] as? Timestamp)?.dateValue() ?? .now

        return PartnerProfile(
            id: partnerID,
            displayName: partnerDisplayName,
            pairedAt: pairedAt
        )
    }
}
