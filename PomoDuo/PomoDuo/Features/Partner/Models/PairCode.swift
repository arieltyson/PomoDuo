import Foundation

/// A short alphanumeric code used to pair two partners.
///
/// The code is always normalized to uppercase and stored as exactly 6 characters.
struct PairCode: Sendable, Equatable, Hashable, Codable {
    /// The number of characters in a valid code.
    ///
    /// `nonisolated` so the parity guards in `DeepLinkRouter` (which
    /// is itself `nonisolated`) can read the canonical length
    /// without crossing actor boundaries. The value is immutable,
    /// pure-compile-time data — there's no state to synchronize.
    nonisolated static let length = 6

    /// The normalized code value.
    let value: String

    nonisolated private static let alphabet = Array(
        "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    )
    nonisolated private static let allowedCharacters = Set(alphabet)

    /// Creates a validated pairing code from user input.
    ///
    /// Supports values with spaces or dashes (for example, `ABC-234`).
    init?(_ raw: String) {
        let normalized =
            raw
            .replacing("-", with: "")
            .replacing(" ", with: "")
            .uppercased()

        guard normalized.count == Self.length else {
            return nil
        }

        guard normalized.allSatisfy({ Self.allowedCharacters.contains($0) })
        else {
            return nil
        }

        value = normalized
    }

    private init(validated value: String) {
        self.value = value
    }

    /// Generates a random code from the allowed alphabet.
    static func generate() -> PairCode {
        var generated = ""
        generated.reserveCapacity(Self.length)

        for _ in 0..<Self.length {
            if let character = Self.alphabet.randomElement() {
                generated.append(character)
            }
        }

        return PairCode(validated: generated)
    }

    /// A display-friendly format, for example `ABC-234`.
    var displayValue: String {
        let splitIndex = value.index(
            value.startIndex,
            offsetBy: Self.length / 2
        )
        return "\(value[..<splitIndex])-\(value[splitIndex...])"
    }

    /// Whether `raw` is *already* in canonical form — exactly
    /// ``length`` uppercase characters drawn from ``alphabet``, with
    /// no separators.
    ///
    /// Use this at ingress boundaries (``DeepLinkRouter``,
    /// `RootView.handleDeepLink`) where we want to accept a URL
    /// segment *only* if it matches the exact shape the Firestore
    /// rules and the `pair.html` web fallback will also accept —
    /// without the space/dash normalization the full `init?(_:)`
    /// performs. This lets a malformed deep-link segment be
    /// rejected at the parse boundary so the user doesn't end up
    /// staring at a code-entry sheet pre-filled with garbage.
    ///
    /// Declared `nonisolated` so it can be called from the project's
    /// `nonisolated` deep-link parser without crossing actor
    /// boundaries — the check is pure over `Character`-set
    /// membership and has no observable state to synchronize.
    nonisolated static func isCanonicalForm(_ raw: String) -> Bool {
        guard raw.count == Self.length else { return false }
        return raw.allSatisfy(Self.allowedCharacters.contains(_:))
    }

    /// The canonical alphabet, exposed read-only so tests and other
    /// boundary guards can reference one source of truth instead of
    /// hand-copying the alphabet string. The same 32-character set
    /// is hard-coded in `firestore.rules` and `pair.html`; parity
    /// tests in the backend repo pin all three against shared
    /// fixtures.
    nonisolated static var canonicalAlphabet: String {
        String(alphabet)
    }
}
