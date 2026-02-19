import Foundation
import Testing

@testable import PomoDuo

// MARK: - AuthProvider

@Suite("AuthProvider")
struct AuthProviderTests {
    @Test("Raw values round-trip")
    func rawValueRoundTrip() {
        #expect(AuthProvider(rawValue: "anonymous") == .anonymous)
        #expect(AuthProvider(rawValue: "apple") == .apple)
        #expect(AuthProvider(rawValue: "email") == .email)
        #expect(AuthProvider(rawValue: "unknown") == nil)
    }
}

// MARK: - AuthUser

@Suite("AuthUser - Apple Extensions")
struct AuthUserAppleTests {
    @Test("Apple user is persistent")
    func appleUserIsPersistent() {
        let user = AuthUser(
            id: "apple-123",
            displayName: "Jane",
            isAnonymous: false,
            createdAt: .now,
            email: "jane@icloud.com",
            authProvider: .apple
        )

        #expect(user.isPersistent)
        #expect(user.authProvider == .apple)
        #expect(user.email == "jane@icloud.com")
    }

    @Test("Anonymous user is not persistent")
    func anonymousIsNotPersistent() {
        let user = AuthUser(
            id: "anon-123",
            displayName: "Focus Friend",
            isAnonymous: true,
            createdAt: .now
        )

        #expect(!user.isPersistent)
        #expect(user.authProvider == .anonymous)
        #expect(user.email == nil)
    }

    @Test("Default values maintain backward compatibility")
    func backwardCompatibility() {
        let user = AuthUser(
            id: "legacy",
            displayName: "Old User",
            isAnonymous: true,
            createdAt: .now
        )

        #expect(user.email == nil)
        #expect(user.authProvider == .anonymous)
    }
}

// MARK: - AppleAuthCredential

@Suite("AppleAuthCredential")
struct AppleAuthCredentialTests {
    @Test("Stores all fields")
    func storesFields() {
        var nameComponents = PersonNameComponents()
        nameComponents.givenName = "Jane"
        nameComponents.familyName = "Doe"

        let credential = AppleAuthCredential(
            idToken: "eyJhbGciOiJSUzI1NiJ9.test",
            nonce: "abc123",
            fullName: nameComponents,
            email: "jane@icloud.com"
        )

        #expect(credential.idToken == "eyJhbGciOiJSUzI1NiJ9.test")
        #expect(credential.nonce == "abc123")
        #expect(credential.fullName?.givenName == "Jane")
        #expect(credential.email == "jane@icloud.com")
    }

    @Test("Handles nil optional fields")
    func handlesNilFields() {
        let credential = AppleAuthCredential(
            idToken: "token",
            nonce: "nonce",
            fullName: nil,
            email: nil
        )

        #expect(credential.fullName == nil)
        #expect(credential.email == nil)
    }
}

// MARK: - AppleSignInCoordinator - Nonce Generation

@Suite("AppleSignInCoordinator - Cryptography")
@MainActor
struct AppleSignInCoordinatorCryptoTests {
    @Test("Random nonce produces correct length")
    func nonceLength() {
        let nonce = AppleSignInCoordinator.randomNonceString(length: 32)
        #expect(nonce.count == 32)
    }

    @Test("Random nonce contains only hex characters")
    func nonceCharacterSet() {
        let nonce = AppleSignInCoordinator.randomNonceString(length: 64)
        let hexCharacters = CharacterSet(charactersIn: "0123456789abcdef")

        for character in nonce.unicodeScalars {
            #expect(hexCharacters.contains(character))
        }
    }

    @Test("Two nonces are distinct")
    func noncesAreUnique() {
        let nonce1 = AppleSignInCoordinator.randomNonceString()
        let nonce2 = AppleSignInCoordinator.randomNonceString()
        #expect(nonce1 != nonce2)
    }

    @Test("SHA256 produces consistent output")
    func sha256Consistency() {
        let hash1 = AppleSignInCoordinator.sha256("test-nonce")
        let hash2 = AppleSignInCoordinator.sha256("test-nonce")
        #expect(hash1 == hash2)
    }

    @Test("SHA256 produces different output for different inputs")
    func sha256Uniqueness() {
        let hash1 = AppleSignInCoordinator.sha256("nonce-a")
        let hash2 = AppleSignInCoordinator.sha256("nonce-b")
        #expect(hash1 != hash2)
    }

    @Test("SHA256 produces 64-character hex string")
    func sha256Length() {
        let hash = AppleSignInCoordinator.sha256("any-input")
        #expect(hash.count == 64)
    }
}

// MARK: - MockAuthService - Apple Sign-In

@Suite("MockAuthService - Apple Sign-In")
@MainActor
struct MockAuthServiceAppleTests {
    private func makeDefaults() -> UserDefaults {
        let suiteName = "com.pomoduo.tests.apple.\(UUID().uuidString)"
        if let defaults = UserDefaults(suiteName: suiteName) {
            defaults.removePersistentDomain(forName: suiteName)
            return defaults
        }

        return .standard
    }

    private func makeService() -> MockAuthService {
        MockAuthService(simulatedDelay: .zero, userDefaults: makeDefaults())
    }

    private func makeAppleCredential(
        name: String? = "Jane Doe",
        email: String? = "jane@icloud.com"
    ) -> AppleAuthCredential {
        var nameComponents: PersonNameComponents?
        if let name {
            var components = PersonNameComponents()
            let parts = name.split(separator: " ")
            components.givenName = String(parts.first ?? "")
            if parts.count > 1 {
                components.familyName = String(parts.last ?? "")
            }
            nameComponents = components
        }

        return AppleAuthCredential(
            idToken: "mock-id-token",
            nonce: "mock-nonce",
            fullName: nameComponents,
            email: email
        )
    }

    @Test("Sign in with Apple creates non-anonymous user")
    func signInCreatesUser() async throws {
        let service = makeService()
        let credential = makeAppleCredential()

        let user = try await service.signInWithApple(credential: credential)

        #expect(!user.isAnonymous)
        #expect(user.authProvider == .apple)
        #expect(user.email == "jane@icloud.com")
    }

    @Test("Link preserves existing user ID")
    func linkPreservesID() async throws {
        let service = makeService()

        // Start as anonymous.
        let anonymous = try await service.signInAnonymously()
        #expect(anonymous.isAnonymous)
        let originalID = anonymous.id

        // Link Apple credential.
        let credential = makeAppleCredential()
        let linked = try await service.linkAppleCredential(credential)

        #expect(linked.id == originalID)
        #expect(!linked.isAnonymous)
        #expect(linked.authProvider == .apple)
    }

    @Test("Link without authenticated user throws")
    func linkWithoutUserThrows() async throws {
        let service = makeService()
        let credential = makeAppleCredential()

        await #expect(throws: AuthServiceError.self) {
            try await service.linkAppleCredential(credential)
        }
    }

    @Test("Link preserves creation date")
    func linkPreservesCreationDate() async throws {
        let service = makeService()

        let anonymous = try await service.signInAnonymously()
        let originalDate = anonymous.createdAt

        let credential = makeAppleCredential()
        let linked = try await service.linkAppleCredential(credential)

        #expect(linked.createdAt == originalDate)
    }

    @Test("Apple sign-in with nil name uses fallback")
    func nilNameFallback() async throws {
        let service = makeService()

        let credential = AppleAuthCredential(
            idToken: "token",
            nonce: "nonce",
            fullName: nil,
            email: nil
        )

        let user = try await service.signInWithApple(credential: credential)
        #expect(!user.displayName.isEmpty)
    }
}

// MARK: - AuthManager - Apple Integration

@Suite("AuthManager - Apple Flow")
@MainActor
struct AuthManagerAppleTests {
    private func makeDefaults() -> UserDefaults {
        let suiteName = "com.pomoduo.tests.manager.\(UUID().uuidString)"
        if let defaults = UserDefaults(suiteName: suiteName) {
            defaults.removePersistentDomain(forName: suiteName)
            return defaults
        }

        return .standard
    }

    private func makeManager() -> AuthManager {
        let service = MockAuthService(
            simulatedDelay: .zero,
            userDefaults: makeDefaults()
        )
        return AuthManager(authService: service)
    }

    @Test("Anonymous user is not persistent")
    func anonymousNotPersistent() async {
        let manager = makeManager()
        await manager.signInAnonymously()

        #expect(!manager.isAccountPersistent)
    }

    @Test("AuthState transitions through anonymous flow")
    func stateTransitions() async {
        let manager = makeManager()

        #expect(manager.authState == .unknown)

        await manager.signInAnonymously()
        #expect(manager.isSignedIn)
        #expect(manager.currentUser?.isAnonymous == true)
    }

    @Test("clearError resets authError")
    func clearErrorWorks() {
        let manager = makeManager()
        manager.clearError()
        #expect(manager.authError == nil)
    }
}

// MARK: - AccountViewModel - Apple

@Suite("AccountViewModel - Apple Upgrade")
@MainActor
struct AccountViewModelAppleTests {
    private func makeDefaults() -> UserDefaults {
        let suiteName = "com.pomoduo.tests.acctvm.\(UUID().uuidString)"
        if let defaults = UserDefaults(suiteName: suiteName) {
            defaults.removePersistentDomain(forName: suiteName)
            return defaults
        }

        return .standard
    }

    private func makeAuthManager() async -> AuthManager {
        let service = MockAuthService(
            simulatedDelay: .zero,
            userDefaults: makeDefaults()
        )
        let manager = AuthManager(authService: service)
        await manager.signInAnonymously()
        return manager
    }

    @Test("canUpgradeToApple is true for anonymous user")
    func canUpgradeAnonymous() async {
        let manager = await makeAuthManager()
        let viewModel = AccountViewModel(authManager: manager)

        #expect(viewModel.canUpgradeToApple)
    }

    @Test("accountTypeLabel reflects provider")
    func accountTypeLabel() async {
        let manager = await makeAuthManager()
        let viewModel = AccountViewModel(authManager: manager)

        #expect(viewModel.accountTypeLabel == "Guest")
    }
}

// MARK: - AppleSignInError

@Suite("AppleSignInError")
struct AppleSignInErrorTests {
    @Test("Cancelled error has description")
    func cancelledDescription() {
        let error = AppleSignInError.cancelled
        #expect(error.errorDescription != nil)
    }

    @Test("Missing token error has description")
    func missingTokenDescription() {
        let error = AppleSignInError.missingIdentityToken
        #expect(error.errorDescription != nil)
    }

    @Test("Authorization failed includes reason")
    func authorizationFailedReason() {
        let error = AppleSignInError.authorizationFailed("Network timeout")
        #expect(error.errorDescription?.contains("Network timeout") == true)
    }

    @Test("Equatable conformance works")
    func equatable() {
        #expect(AppleSignInError.cancelled == AppleSignInError.cancelled)
        #expect(
            AppleSignInError.cancelled
                != AppleSignInError.missingIdentityToken
        )
    }
}

// MARK: - AuthServiceError

@Suite("AuthServiceError - Apple Extensions")
struct AuthServiceErrorAppleTests {
    @Test("Apple sign-in error has description")
    func appleSignInError() {
        let error = AuthServiceError.appleSignInFailed("Token expired")
        #expect(error.errorDescription?.contains("Token expired") == true)
    }

    @Test("Credential linking error has description")
    func credentialLinkingError() {
        let error = AuthServiceError.credentialLinkingFailed("Already linked")
        #expect(error.errorDescription?.contains("Already linked") == true)
    }
}
