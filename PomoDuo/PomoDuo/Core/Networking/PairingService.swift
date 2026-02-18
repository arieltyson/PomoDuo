import Foundation

/// Backend abstraction for partner pairing operations.
protocol PairingService: Sendable {
    /// Publishes a generated code so another user can discover this device.
    func publishCode(_ code: PairCode) async throws -> Bool

    /// Attempts to join an existing partner using an entered code.
    func joinWithCode(_ code: PairCode) async throws -> PartnerProfile?

    /// Emits when a partner joins the currently published code.
    func waitForPartner(code: PairCode) -> AsyncStream<PartnerProfile>

    /// Clears any remote pairing state.
    func unpair() async throws

    /// Returns an existing partner if one is currently connected.
    func currentPartner() async throws -> PartnerProfile?
}
