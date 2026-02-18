import Foundation
import Observation
import OSLog
@preconcurrency import FirebaseFirestore

/// Writes a once-per-minute heartbeat to the active session document
/// and monitors the partner's heartbeat for staleness.
///
/// If the partner's heartbeat is older than ``staleThreshold``, the
/// manager marks ``isPartnerActive`` as `false` so the UI can show
/// a warning. If the heartbeat exceeds ``autoEndThreshold``, the
/// manager invokes the ``onPartnerStale`` callback so the session
/// can be auto-ended gracefully.
///
/// Cost impact: ~25 writes per 25-minute session per device (1/min),
/// well within Firestore Spark plan free tier.
@MainActor
@Observable
final class HeartbeatManager {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.arieljtyson.PomoDuo",
        category: "HeartbeatManager"
    )

    /// Duration between heartbeat writes.
    static let beatInterval: Duration = .seconds(60)

    /// Partner heartbeat older than this -> show warning.
    static let staleThreshold: TimeInterval = 3 * 60

    /// Partner heartbeat older than this -> auto-end session.
    static let autoEndThreshold: TimeInterval = 5 * 60

    // MARK: - Observable State

    /// Whether the partner's heartbeat is recent enough to be considered active.
    private(set) var isPartnerActive = true

    /// The partner's last known heartbeat timestamp, if available.
    private(set) var partnerLastSeen: Date?

    // MARK: - Private State

    private let database: Firestore
    private var heartbeatTask: Task<Void, Never>?
    private var monitorTask: Task<Void, Never>?
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

        // Monitor partner's heartbeat every 60s.
        monitorTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                try? await Task.sleep(for: Self.beatInterval)
                guard !Task.isCancelled else { return }
                await self.checkPartnerHeartbeat()
            }
        }
    }

    /// Stops all heartbeat activity.
    ///
    /// Call this when the session ends, is cleared, or the user signs out.
    func stopBeating() {
        heartbeatTask?.cancel()
        heartbeatTask = nil
        monitorTask?.cancel()
        monitorTask = nil
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

    private func checkPartnerHeartbeat() async {
        guard let sessionID = currentSessionID,
            let partnerID = currentPartnerID
        else { return }

        do {
            let snapshot = try await database
                .collection("sessions")
                .document(sessionID)
                .getDocument()

            guard let data = snapshot.data(),
                let heartbeats = data["heartbeats"] as? [String: Any],
                let partnerTimestamp = heartbeats[partnerID] as? Timestamp
            else {
                // No heartbeat data yet - partner may not have written one.
                return
            }

            let partnerDate = partnerTimestamp.dateValue()
            partnerLastSeen = partnerDate

            let elapsed = Date.now.timeIntervalSince(partnerDate)

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
        } catch {
            Self.logger.warning(
                "Partner heartbeat check failed: \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}
