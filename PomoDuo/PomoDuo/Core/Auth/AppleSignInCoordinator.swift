import AuthenticationServices
import CryptoKit
import Foundation

/// Coordinates the Sign in with Apple authorization flow.
///
/// Generates a cryptographic nonce, presents the system sign-in sheet,
/// and returns an ``AppleAuthCredential`` on success. The credential
/// can then be passed to ``AuthService/signInWithApple(credential:)``
/// or ``AuthService/linkAppleCredential(_:)`` for backend integration.
@MainActor
final class AppleSignInCoordinator: NSObject {
    private var activeAuthorizationController: ASAuthorizationController?
    private var activeDelegate: AuthorizationDelegate?

    /// Performs the full Sign in with Apple flow.
    ///
    /// - Returns: An ``AppleAuthCredential`` containing the identity token
    ///   and any first-time user information.
    /// - Throws: ``AppleSignInError`` if the user cancels or
    ///   authorization fails.
    func signIn() async throws -> AppleAuthCredential {
        let nonce = Self.randomNonceString()
        let hashedNonce = Self.sha256(nonce)

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = hashedNonce

        let authorization = try await performAuthorization(request: request)
        return try extractCredential(from: authorization, rawNonce: nonce)
    }

    // MARK: - Authorization

    private func performAuthorization(
        request: ASAuthorizationAppleIDRequest
    ) async throws -> ASAuthorization {
        try await withCheckedThrowingContinuation { continuation in
            let controller = ASAuthorizationController(
                authorizationRequests: [request]
            )

            let delegate = AuthorizationDelegate(
                continuation: continuation,
                onCompletion: { [weak self] in
                    self?.activeAuthorizationController = nil
                    self?.activeDelegate = nil
                }
            )

            // Keep references alive for the duration of the request.
            activeAuthorizationController = controller
            activeDelegate = delegate

            controller.delegate = delegate
            controller.performRequests()
        }
    }

    private func extractCredential(
        from authorization: ASAuthorization,
        rawNonce: String
    ) throws -> AppleAuthCredential {
        guard
            let appleIDCredential = authorization.credential
                as? ASAuthorizationAppleIDCredential,
            let identityTokenData = appleIDCredential.identityToken,
            let idToken = String(data: identityTokenData, encoding: .utf8)
        else {
            throw AppleSignInError.missingIdentityToken
        }

        return AppleAuthCredential(
            idToken: idToken,
            nonce: rawNonce,
            fullName: appleIDCredential.fullName,
            email: appleIDCredential.email
        )
    }

    // MARK: - Cryptographic Nonce

    /// Generates a random nonce encoded as lowercase hexadecimal.
    static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0, "Nonce length must be greater than zero.")

        var randomBytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(
            kSecRandomDefault,
            randomBytes.count,
            &randomBytes
        )
        precondition(status == errSecSuccess, "Failed to generate random bytes")

        let charset: [Character] = Array("0123456789abcdef")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    /// SHA256 hash of a string, returned as a lowercase hex string.
    static func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

/// Errors specific to the Apple Sign-In authorization flow.
enum AppleSignInError: LocalizedError, Sendable, Equatable {
    case cancelled
    case missingIdentityToken
    case authorizationFailed(String)

    var errorDescription: String? {
        switch self {
        case .cancelled:
            "Sign in was cancelled."
        case .missingIdentityToken:
            "Apple did not return an identity token."
        case .authorizationFailed(let reason):
            "Authorization failed: \(reason)"
        }
    }
}

/// Bridges delegate callbacks to Swift concurrency continuations.
private final class AuthorizationDelegate:
    NSObject, ASAuthorizationControllerDelegate
{
    private var continuation: CheckedContinuation<ASAuthorization, Error>?
    private let onCompletion: () -> Void

    init(
        continuation: CheckedContinuation<ASAuthorization, Error>,
        onCompletion: @escaping () -> Void
    ) {
        self.continuation = continuation
        self.onCompletion = onCompletion
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        continuation?.resume(returning: authorization)
        continuation = nil
        onCompletion()
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        let nsError = error as NSError
        if nsError.domain == ASAuthorizationError.errorDomain,
            nsError.code == ASAuthorizationError.canceled.rawValue
        {
            continuation?.resume(throwing: AppleSignInError.cancelled)
        } else {
            continuation?.resume(
                throwing: AppleSignInError.authorizationFailed(
                    error.localizedDescription
                )
            )
        }
        continuation = nil
        onCompletion()
    }
}
