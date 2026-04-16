import AuthenticationServices
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

    /// Whether the current account is linked to a persistent identity
    /// that survives reinstalls.
    var isAccountPersistent: Bool {
        currentUser?.isPersistent ?? false
    }

    private let authService: any AuthService
    private let appleSignInCoordinator = AppleSignInCoordinator()
    private var stateListenerTask: Task<Void, Never>?
    private var revocationListenerTask: Task<Void, Never>?

    init(authService: any AuthService = MockAuthService()) {
        self.authService = authService
    }

    /// Starts auth lifecycle observation and signs in anonymously if needed.
    ///
    /// Bootstrap runs **before** the state listener subscribes. The auth
    /// service's state stream (Firebase's `addStateDidChangeListener` and
    /// ``MockAuthService/authStateChanges()``) yields its current value at
    /// subscription time — which is `nil` on a cold start. Subscribing before
    /// bootstrap would buffer that `nil` and then race with the direct
    /// `authState` mutations in ``signInAnonymously()`` / ``updateDisplayName(_:)``,
    /// causing `authState` to transiently regress to `.signedOut` (or an
    /// older user) whenever the listener drained its backlog after a direct
    /// write. Bootstrapping first makes the listener's very first emission
    /// equal to the user that direct writes already established.
    func start() async {
        if let existing = await authService.currentUser {
            authState = .signedIn(existing)
        } else {
            await signInAnonymously()
        }

        startListeningForStateChanges()
        startListeningForAppleRevocation()
    }

    func stop() {
        stateListenerTask?.cancel()
        stateListenerTask = nil
        revocationListenerTask?.cancel()
        revocationListenerTask = nil
    }

    // MARK: - Anonymous

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

    // MARK: - Email

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

    // MARK: - Sign in with Apple

    /// Performs a full Sign in with Apple flow (new or returning user).
    ///
    /// Use this when no user is signed in, or to replace an anonymous
    /// session with a persistent Apple identity.
    func signInWithApple() async {
        isLoading = true
        authError = nil
        defer {
            isLoading = false
        }

        do {
            let credential = try await appleSignInCoordinator.signIn()
            let user = try await authService.signInWithApple(
                credential: credential
            )
            authState = .signedIn(user)
        } catch AppleSignInError.cancelled {
            // User cancelled intentionally — no error message needed.
        } catch {
            authError =
                "Sign in with Apple failed: \(error.localizedDescription)"
        }
    }

    /// Links an Apple credential to the current anonymous account.
    ///
    /// This preserves the existing user ID and all associated data
    /// (partnerships, session history, widget stats) while upgrading
    /// the account to a persistent identity.
    func linkWithApple() async {
        isLoading = true
        authError = nil
        defer {
            isLoading = false
        }

        do {
            let credential = try await appleSignInCoordinator.signIn()
            let user = try await authService.linkAppleCredential(credential)
            authState = .signedIn(user)
        } catch AppleSignInError.cancelled {
            // User cancelled intentionally — no error message needed.
        } catch {
            authError =
                "Could not link Apple ID: \(error.localizedDescription)"
        }
    }

    // MARK: - Account Management

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
        isLoading = true
        authError = nil
        defer {
            isLoading = false
        }

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

    #if DEBUG
    /// Test-only hook that forwards a synthetic stream emission through the
    /// same reconciliation path the real listener uses.
    ///
    /// Used to deterministically reproduce — and prove the fix for — the
    /// stale-emission race that caused `savePropagatesDisplayName` to flake.
    func simulateStreamEmissionForTests(_ user: AuthUser?) {
        applyStreamEmission(user)
    }
    #endif

    // MARK: - State Listeners

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

                self.applyStreamEmission(user)
            }
        }
    }

    /// Reconciles a stream emission with the current ``authState``.
    ///
    /// The stream is authoritative for identity transitions (sign-in,
    /// sign-out, user switch). It is **not** authoritative for profile
    /// updates on the same identity — those ride on direct writes in
    /// ``updateDisplayName(_:)`` and ``linkWithApple()``. A subscription-time
    /// snapshot of the user can otherwise replay *after* a direct write
    /// completes and clobber the fresh profile data with an older copy.
    private func applyStreamEmission(_ emitted: AuthUser?) {
        switch (authState, emitted) {
        case (.signedIn(let current), .some(let incoming))
        where current.id == incoming.id:
            // Same identity — keep whatever the direct writes established.
            // Firebase's state listener never fires for profile-only
            // changes, so production won't miss real updates by skipping
            // this emission; ``MockAuthService`` does fire, and the skip
            // is what keeps the test flake from recurring.
            break
        case (_, .some(let incoming)):
            authState = .signedIn(incoming)
        case (_, .none):
            authState = .signedOut
        }
    }

    /// Listens for Apple credential revocation (Settings -> Apple ID).
    private func startListeningForAppleRevocation() {
        revocationListenerTask?.cancel()

        revocationListenerTask = Task { [weak self] in
            let notifications = NotificationCenter.default.notifications(
                named: ASAuthorizationAppleIDProvider
                    .credentialRevokedNotification
            )

            for await _ in notifications {
                guard !Task.isCancelled, let self else {
                    return
                }

                if self.currentUser?.authProvider == .apple {
                    await self.signOut()
                }
            }
        }
    }
}
