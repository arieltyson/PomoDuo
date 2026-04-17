import Foundation

/// Single source of truth for "is this string a usable username?".
///
/// Every layer that handles a username — link generation, deep-link
/// parsing, view-layer ingress, and the Firestore service — funnels
/// through ``normalize(_:)`` so the precondition is enforced
/// consistently. The Firestore SDK throws `FIRInvalidArgumentException`
/// with `"Document path cannot be empty."` when an empty string is
/// passed to `CollectionReference.document(_:)` (Firestore's own
/// invariant: per
/// <https://firebase.google.com/docs/reference/swift/firebasefirestore/api/reference/Classes/CollectionReference>,
/// document IDs must be non-empty), so a single missed guard anywhere
/// upstream becomes a crash. Centralizing the normalization here
/// eliminates the class of bug rather than the one symptom.
///
/// **Normalization rules.**
///
/// 1. Strip leading and trailing whitespace and newlines. A username
///    that's purely whitespace (`"   "`, a stray newline pasted from
///    iMessage) is semantically empty.
/// 2. Lowercase the result. Usernames are stored, looked up, and
///    compared in the canonical lowercased form across the app.
/// 3. Return `nil` when the result is empty. Callers are expected to
///    treat `nil` as "no usable username here" — never to fall through
///    to a Firestore document lookup.
///
/// **Why this is `nonisolated enum`.** Pure value-level utility with
/// no observable state; safe to call from any actor or extension
/// process (Shield / Monitor / Widget) without isolation overhead.
nonisolated enum UsernameNormalizer {

    /// Trims, lowercases, and returns `nil` for empty/whitespace-only
    /// input. The non-`nil` result is the canonical form callers
    /// should pass to Firestore document lookups.
    static func normalize(_ raw: String) -> String? {
        let trimmed = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Convenience that mirrors ``normalize(_:)`` for `Optional`
    /// inputs. Returns `nil` for both a `nil` input and a non-`nil`
    /// input that normalizes to empty.
    static func normalize(_ raw: String?) -> String? {
        guard let raw else { return nil }
        return normalize(raw)
    }

    /// Cheap predicate used by UI layers that need to decide whether
    /// to render a "share my profile" affordance without running a
    /// full Firestore round-trip first.
    static func isUsable(_ raw: String?) -> Bool {
        normalize(raw) != nil
    }

    // MARK: - Format Contract (Parity with Backend)

    /// Minimum username length, mirrored in `firestore.rules` and
    /// `add-friend.html` so all three boundaries enforce the same
    /// shape. Matches ``UsernameValidationResult/minLength`` (the
    /// claim-time validator); duplicating the constant here avoids a
    /// dependency from the networking layer up into the friends
    /// feature folder.
    static let minLength = 3
    /// Maximum username length, same parity with backend.
    static let maxLength = 20

    /// Whether a *raw* string (deep-link path component, share-sheet
    /// payload, etc.) matches the canonical username format the
    /// backend will accept and the web fallback will recognize as a
    /// real invite.
    ///
    /// **Format**: 3–20 characters, ASCII letters, digits, and
    /// underscores. Identical to:
    ///
    /// - `firestore.rules` regex `^[a-zA-Z0-9_]{3,20}$` on
    ///   `users/{uid}.username` and `usernames/{normalized}` doc IDs.
    /// - `add-friend.html` `^[a-z0-9_]{3,20}$` (post-lowercase).
    /// - ``UsernameValidationResult`` claim-time validator (same
    ///   length range, same character set).
    ///
    /// Returns `false` for empty/whitespace input. Returns `true`
    /// only when every codepoint is allowed and the trimmed length
    /// is in range. The check is case-insensitive — links and rules
    /// agree on lowercase canonicalization, but a mixed-case raw
    /// input is still a *valid* link (`add-friend/Ariel` is allowed
    /// and routes the same as `add-friend/ariel`).
    static func isValidLinkFormat(_ raw: String) -> Bool {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= minLength, trimmed.count <= maxLength
        else {
            return false
        }
        // Strict ASCII allow-list — must stay byte-for-byte identical
        // to `firestore.rules` (`isValidUsername`'s
        // `[a-zA-Z0-9_]+` regex) and `add-friend.html`'s
        // `/^[a-z0-9_]{3,20}$/`. We deliberately do *not* use
        // `CharacterSet.alphanumerics` here because that set is
        // Unicode-aware and would accept letters like `é` / `ß` that
        // the backend regex rejects, silently breaking parity.
        return trimmed.unicodeScalars.allSatisfy { scalar in
            switch scalar.value {
            case 0x30...0x39,  // 0-9
                0x41...0x5A,   // A-Z
                0x61...0x7A,   // a-z
                0x5F:          // _
                true
            default:
                false
            }
        }
    }
}
