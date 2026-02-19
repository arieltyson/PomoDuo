import Testing

@testable import PomoDuo

private struct PendingPairingService: PairingService {
    func publishCode(_ code: PairCode) async throws -> Bool {
        true
    }

    func joinWithCode(_ code: PairCode) async throws -> PartnerProfile? {
        nil
    }

    func waitForPartner(code: PairCode) -> AsyncStream<PartnerProfile> {
        AsyncStream { _ in }
    }

    func unpair() async throws {}

    func currentPartner() async throws -> PartnerProfile? {
        nil
    }
}

@Suite("PairingViewModel Auth Reset")
@MainActor
struct PairingViewModelAuthTests {
    @Test("Reset clears local pairing state after auth change")
    func resetForSignedOutClearsState() async {
        let viewModel = PairingViewModel(
            pairingService: PendingPairingService()
        )

        await viewModel.generateCode()
        #expect(isWaitingForPartner(viewModel.pairingState))

        viewModel.codeInput = "ABC123"
        viewModel.codeInputIsInvalid = true

        viewModel.resetForSignedOut()

        #expect(viewModel.pairingState == .unpaired)
        #expect(viewModel.codeInput.isEmpty)
        #expect(!viewModel.codeInputIsInvalid)
    }

    private func isWaitingForPartner(_ state: PairingState) -> Bool {
        if case .waitingForPartner = state {
            return true
        }
        return false
    }
}
