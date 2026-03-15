import Foundation
import Observation
import OSLog
@preconcurrency import FirebaseFirestore

/// Writes a heartbeat every two minutes to the active session document
/// and monitors the partner's heartbeat for staleness.
///
/// If the partner's heartbeat is older than ``staleThreshold``, the
/// manager marks ``isPartnerActive`` as `false` so the UI can show
/// a warning. If the heartbeat exceeds ``autoEndThreshold``, the
/// manager invokes the ``onPartnerStale`` callback so the session
/// can be auto-ended gracefully.
///
/// Cost impact: ~13 writes per 25-minute session per device (1/2min),
/// well within Firestore Spark plan free tier.
@MainActor
@Observable
final class HeartbeatManager {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.arieljtyson.PomoDuo",
        category: "HeartbeatManager"
    )

    /// Duration between heartbeat writes.
    static let beatInterval: Duration = .seconds(120)

    /// Partner heartbeat older than this -> show warning.
    static let staleThreshold: TimeInterval = 4 * 60

    /// Partner heartbeat older than this -> auto-end session.
    static let autoEndThreshold: TimeInterval = 7 * 60

    // MARK: - Observable State

    /// Whether the partner's heartbeat is recent enough to be considered active.
    private(set) var isPartnerActive = true

    /// The partner's last known heartbeat timestamp, if available.
    private(set) var partnerLastSeen: Date?

    // MARK: - Private State

    private let database: Firestore
    private var heartbeatTask: Task<Void, Never>?
    private var sessionListener: ListenerRegistration?
    private var currentSessionID: String?
    private var currentUserID: String?
    private var currentPartnerID: String?
    private var onPartnerStale: (() async -> Void)?
    private var didTriggerAutoEnd = false

    init(database: Firestore = Firestore.firestore()) {
        self.database = database
    }

    // MARK: - Public API

    /// Begins heartbeat writes and partner monitoring for the given session.
    ///
    /// - Parameters:
    ///   - sessionID: The active session's Firestore document ID.
    ///   - userID: The current user's UID.
    ///   - partnerID: The partner's UID.
    ///   - onPartnerStale: Called when the partner's heartbeat exceeds
    ///     ``autoEndThreshold``. Typically ends the session gracefully.
    func startBeating(
        sessionID: String,
        userID: String,
        partnerID: String,
        onPartnerStale: @escaping () async -> Void
    ) {
        guard currentSessionID != sessionID else { return }

        stopBeating()

        currentSessionID = sessionID
        currentUserID = userID
        currentPartnerID = partnerID
        self.onPartnerStale = onPartnerStale
        didTriggerAutoEnd = false
        isPartnerActive = true
        partnerLastSeen = nil

        Self.logger.info("Heartbeat started for session \(sessionID, privacy: .public).")

        // Write heartbeat immediately, then every 60s.
        heartbeatTask = Task { [weak self] in
            guard let self else { return }

            await self.writeHeartbeat()

            while !Task.isCancelled {
                try? await Task.sleep(for: Self.beatInterval)
                guard !Task.isCancelled else { return }
                await self.writeHeartbeat()
            }
        }

        sessionListener = database
            .collection("sessions")
            .document(sessionID)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    await self.handleHeartbeatSnapshot(snapshot, error: error)
                }
            }
    }

    /// Stops all heartbeat activity.
    ///
    /// Call this when the session ends, is cleared, or the user signs out.
    func stopBeating() {
        heartbeatTask?.cancel()
        heartbeatTask = nil
        sessionListener?.remove()
        sessionListener = nil
        currentSessionID = nil
        currentUserID = nil
        currentPartnerID = nil
        onPartnerStale = nil
        didTriggerAutoEnd = false
        isPartnerActive = true
        partnerLastSeen = nil
    }

    // MARK: - Private

    private func writeHeartbeat() async {
        guard let sessionID = currentSessionID,
            let userID = currentUserID
        else { return }

        let data: [String: Any] = [
            "heartbeats.\(userID)": FieldValue.serverTimestamp()
        ]

        do {
            try await database
                .collection("sessions")
                .document(sessionID)
                .updateData(data)
        } catch {
            Self.logger.warning(
                "Heartbeat write failed: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    private func handleHeartbeatSnapshot(
        _ snapshot: DocumentSnapshot?,
        error: Error?
    ) async {
        if let error {
            Self.logger.warning(
                "Partner heartbeat observation failed: \(error.localizedDescription, privacy: .public)"
            )
            return
        }

        guard let partnerID = currentPartnerID,
            let data = snapshot?.data(),
            let heartbeats = data["heartbeats"] as? [String: Any]
        else {
            return
        }

        let partnerTimestamp = heartbeats[partnerID] as? Timestamp
        await ingestPartnerHeartbeat(
            partnerTimestamp?.dateValue()
        )
    }

    /// Processes the latest known partner heartbeat timestamp.
    ///
    /// The active session document listener calls this whenever heartbeat data
    /// changes so partner presence can be updated without an additional poll.
    func ingestPartnerHeartbeat(
        _ partnerDate: Date?,
        referenceDate: Date = .now
    ) async {
        guard let partnerDate else {
            return
        }

        partnerLastSeen = partnerDate

        let elapsed = referenceDate.timeIntervalSince(partnerDate)

        if elapsed > Self.autoEndThreshold {
            Self.logger.warning(
                "Partner heartbeat stale for \(Int(elapsed))s - triggering auto-end."
            )
            isPartnerActive = false

            guard !didTriggerAutoEnd else { return }
            didTriggerAutoEnd = true
            await onPartnerStale?()
        } else if elapsed > Self.staleThreshold {
            Self.logger.notice(
                "Partner heartbeat stale for \(Int(elapsed))s - showing warning."
            )
            isPartnerActive = false
            didTriggerAutoEnd = false
        } else {
            isPartnerActive = true
            didTriggerAutoEnd = false
        }
    }
}
