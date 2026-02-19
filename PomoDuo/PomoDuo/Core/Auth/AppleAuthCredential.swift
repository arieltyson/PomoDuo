import Foundation

/// Backend-agnostic representation of a Sign in with Apple authorization.
///
/// This type decouples the ASAuthorization result from the auth service
/// implementation, keeping the ``AuthService`` protocol testable without
/// importing AuthenticationServices.
struct AppleAuthCredential: Sendable {
    /// JWT identity token issued by Apple.
    let idToken: String

    /// Cryptographic nonce used to prevent replay attacks.
    let nonce: String

    /// User's full name, provided only on the first authorization.
    ///
    /// Apple sends the name exactly once — on subsequent sign-ins this
    /// is `nil`. The auth service must persist the name on first use.
    let fullName: PersonNameComponents?

    /// User's email, provided only on the first authorization.
    let email: String?
}
