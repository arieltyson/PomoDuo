//
//  PairCode.swift
//  PomoDuo
//
//  Created by Codex on 2/15/26.
//

import Foundation

/// A short alphanumeric code used to pair two partners.
///
/// The code is always normalized to uppercase and stored as exactly 6 characters.
struct PairCode: Sendable, Equatable, Hashable, Codable {
    /// The number of characters in a valid code.
    static let length = 6

    /// The normalized code value.
    let value: String

    private static let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
    private static let allowedCharacters = Set(alphabet)

    /// Creates a validated pairing code from user input.
    ///
    /// Supports values with spaces or dashes (for example, `ABC-234`).
    init?(_ raw: String) {
        let normalized = raw
            .replacing("-", with: "")
            .replacing(" ", with: "")
            .uppercased()

        guard normalized.count == Self.length else {
            return nil
        }

        guard normalized.allSatisfy({ Self.allowedCharacters.contains($0) }) else {
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
        let splitIndex = value.index(value.startIndex, offsetBy: Self.length / 2)
        return "\(value[..<splitIndex])-\(value[splitIndex...])"
    }
}
