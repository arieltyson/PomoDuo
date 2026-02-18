import Foundation

/// Abstracts the real-time sync layer so the app logic is backend-agnostic.
/// Firebase, CloudKit, or a mock can all conform to this.
protocol SessionSyncService: Actor, Sendable {
    /// Writes a session state transition to the remote backend.
    func writeSession(_ session: StudySession) async throws

    /// Returns a stream of remote session changes to react to.
    func sessionStream(for sessionID: String) -> AsyncStream<StudySession>

    /// Creates a new session document and returns its ID.
    func createSession(_ session: StudySession) async throws -> String

    /// Removes the active session document (for example, on completion).
    func deleteSession(_ sessionID: String) async throws

    /// Returns a stream that emits the user's current active session, or `nil`
    /// when no in-progress session exists.
    ///
    /// The sync layer watches for sessions where the given user is a member
    /// and filters out sessions in terminal states (`.completed`, `.idle`).
    func activeSessionStream(for userID: String) -> AsyncStream<StudySession?>
}
