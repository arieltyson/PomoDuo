import Foundation
import Observation

/// Lifecycle state for authentication.
enum AuthState: Equatable, Sendable {
    case unknown
    case signedOut
    case signedIn(AuthUser)
}

/// Main-actor observable auth coordinator used by SwiftUI.
@MainActor
@Observable
final class AuthManager {
    private(set) var authState: AuthState = .unknown
    private(set) var authError: String?
    private(set) var isLoading = false

    var currentUser: AuthUser? {
        if case .signedIn(let user) = authState {
            return user
        }

        return nil
    }

    var isSignedIn: Bool {
        currentUser != nil
    }

    var currentUserID: String? {
        currentUser?.id
    }

    private let authService: any AuthService
    private var stateListenerTask: Task<Void, Never>?

    init(authService: any AuthService = MockAuthService()) {
        self.authService = authService
    }

    /// Starts auth lifecycle observation and signs in anonymously if needed.
    func start() async {
        startListeningForStateChanges()

        if let existing = await authService.currentUser {
            authState = .signedIn(existing)
            return
        }

        await signInAnonymously()
    }

    func stop() {
        stateListenerTask?.cancel()
        stateListenerTask = nil
    }

    func signInAnonymously() async {
        isLoading = true
        authError = nil
        defer {
            isLoading = false
        }

        do {
            let user = try await authService.signInAnonymously()
            authState = .signedIn(user)
        } catch {
            authState = .signedOut
            authError = "Could not sign in: \(error.localizedDescription)"
        }
    }

    func signIn(email: String, password: String) async {
        isLoading = true
        authError = nil
        defer {
            isLoading = false
        }

        do {
            let user = try await authService.signIn(
                email: email,
                password: password
            )
            authState = .signedIn(user)
        } catch {
            authError = "Sign-in failed: \(error.localizedDescription)"
        }
    }

    func createAccount(email: String, password: String, displayName: String)
        async
    {
        isLoading = true
        authError = nil
        defer {
            isLoading = false
        }

        do {
            let user = try await authService.createAccount(
                email: email,
                password: password,
                displayName: displayName
            )
            authState = .signedIn(user)
        } catch {
            authError =
                "Could not create account: \(error.localizedDescription)"
        }
    }

    func signOut() async {
        authError = nil

        do {
            try await authService.signOut()
            authState = .signedOut
        } catch {
            authError = "Could not sign out: \(error.localizedDescription)"
        }
    }

    func deleteAccount() async {
        isLoading = true
        authError = nil
        defer {
            isLoading = false
        }

        do {
            try await authService.deleteAccount()
            authState = .signedOut
        } catch {
            authError =
                "Could not delete account: \(error.localizedDescription)"
        }
    }

    func updateDisplayName(_ name: String) async {
        authError = nil

        do {
            let updated = try await authService.updateDisplayName(name)
            authState = .signedIn(updated)
        } catch {
            authError = "Could not update name: \(error.localizedDescription)"
        }
    }

    func clearError() {
        authError = nil
    }

    private func startListeningForStateChanges() {
        stateListenerTask?.cancel()

        stateListenerTask = Task { [weak self, authService] in
            guard let self else {
                return
            }

            for await user in authService.authStateChanges() {
                guard !Task.isCancelled else {
                    return
                }

                if let user {
                    self.authState = .signedIn(user)
                } else {
                    self.authState = .signedOut
                }
            }
        }
    }
}
