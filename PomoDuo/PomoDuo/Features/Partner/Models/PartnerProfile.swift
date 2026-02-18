import Foundation

/// Lightweight profile for a connected study partner.
struct PartnerProfile: Sendable, Equatable, Codable, Identifiable {
    let id: String
    let displayName: String
    let pairedAt: Date
}
