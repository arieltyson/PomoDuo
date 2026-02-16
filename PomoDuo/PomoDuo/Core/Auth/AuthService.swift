//
//  AuthService.swift
//  PomoDuo
//
//  Created by Codex on 2/16/26.
//

import Foundation

/// Typed auth errors shared by auth service implementations.
enum AuthServiceError: LocalizedError, Sendable {
    case invalidCredentials
    case invalidEmail
    case emptyDisplayName
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            "The credentials are invalid."
        case .invalidEmail:
            "Enter a valid email address."
        case .emptyDisplayName:
            "Display name cannot be empty."
        case .notAuthenticated:
            "No authenticated user is available."
        }
    }
}

/// Backend-agnostic contract for authentication.
protocol AuthService: Sendable {
    /// Currently signed-in identity, if any.
    var currentUser: AuthUser? { get async }

    /// Signs in anonymously.
    func signInAnonymously() async throws -> AuthUser

    /// Signs in with email credentials.
    func signIn(email: String, password: String) async throws -> AuthUser

    /// Creates a new account.
    func createAccount(email: String, password: String, displayName: String) async throws -> AuthUser

    /// Signs out the active user.
    func signOut() async throws

    /// Deletes the active account.
    func deleteAccount() async throws

    /// Updates display name for the active account.
    func updateDisplayName(_ name: String) async throws -> AuthUser

    /// Emits auth state whenever it changes.
    func authStateChanges() -> AsyncStream<AuthUser?>
}
