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
}
