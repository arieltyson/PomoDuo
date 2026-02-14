//
//  SessionSyncService.swift
//  PomoDuo
//
//  Created by Ariel Tyson on 2/14/26.
//

import Foundation

/// Abstracts the real-time sync layer so the app logic is backend-agnostic.
/// Firebase, CloudKit, or a mock can all conform to this.
protocol SessionSyncService: Sendable {
    /// Writes a session state transition to the remote backend.
    func writeSession(_ session: StudySession) async throws

    /// Returns a stream of remote session changes to react to.
    func sessionStream(for sessionID: String) -> AsyncStream<StudySession>

    /// Creates a new session document and returns its ID.
    func createSession(_ session: StudySession) async throws -> String

    /// Removes the active session document (for example, on completion).
    func deleteSession(_ sessionID: String) async throws
}
