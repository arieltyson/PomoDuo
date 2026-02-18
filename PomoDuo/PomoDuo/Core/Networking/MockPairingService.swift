import Foundation

/// Local mock implementation used until Firebase sync is integrated.
struct MockPairingService: PairingService {
    let simulatedDelay: Duration
    let simulatedPartner: PartnerProfile

    init(
        simulatedDelay: Duration = .seconds(2),
        simulatedPartner: PartnerProfile = .init(
            id: "mock-partner-001",
            displayName: "Study Buddy",
            pairedAt: .now
        )
    ) {
        self.simulatedDelay = simulatedDelay
        self.simulatedPartner = simulatedPartner
    }

    func publishCode(_ code: PairCode) async throws -> Bool {
        true
    }

    func joinWithCode(_ code: PairCode) async throws -> PartnerProfile? {
        try await Task.sleep(for: simulatedDelay)
        return simulatedPartner
    }

    func waitForPartner(code: PairCode) -> AsyncStream<PartnerProfile> {
        let partner = simulatedPartner
        let delay = simulatedDelay

        return AsyncStream { continuation in
            let task = Task {
                try? await Task.sleep(for: delay)
                guard !Task.isCancelled else {
                    continuation.finish()
                    return
                }

                continuation.yield(partner)
                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    func unpair() async throws {}

    func currentPartner() async throws -> PartnerProfile? {
        nil
    }
}
