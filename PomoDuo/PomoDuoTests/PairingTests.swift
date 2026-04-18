import Foundation
import Testing

@testable import PomoDuo

@MainActor
struct PairCodeTests {
    private let allowedCharacters = Set("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

    @Test func generatedCodeHasExpectedLength() {
        let code = PairCode.generate()
        #expect(code.value.count == PairCode.length)
    }

    @Test func generatedCodeUsesAllowedCharactersOnly() {
        for _ in 0..<50 {
            let code = PairCode.generate()
            #expect(code.value.allSatisfy { allowedCharacters.contains($0) })
        }
    }

    @Test func initAcceptsValidCode() {
        let code = PairCode("ABC234")
        #expect(code != nil)
        #expect(code?.value == "ABC234")
    }

    @Test func initNormalizesLowercaseAndSeparators() {
        let code = PairCode("abc-234")
        #expect(code?.value == "ABC234")
    }

    @Test func initRejectsInvalidCharacters() {
        #expect(PairCode("ABO234") == nil)
        #expect(PairCode("ABC12I") == nil)
    }

    @Test func initRejectsIncorrectLength() {
        #expect(PairCode("ABC23") == nil)
        #expect(PairCode("ABC2345") == nil)
    }

    @Test func displayValueFormatsWithDash() {
        let code = PairCode("ABC234")
        #expect(code?.displayValue == "ABC-234")
    }

    // MARK: - Canonical-Form Parity (Deep-Link Ingress Contract)

    /// `isCanonicalForm(_:)` is the strict "already canonical" check
    /// used by ``DeepLinkRouter`` to reject malformed pair-code
    /// deep links at the parse boundary. It must match
    /// `firestore.rules` `isValidPairCode` and `pair.html`'s
    /// `/^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}$/` byte-for-byte.

    @Test func isCanonicalFormAcceptsValidCode() {
        #expect(PairCode.isCanonicalForm("ABC234"))
        #expect(PairCode.isCanonicalForm("XYZ789"))
        #expect(PairCode.isCanonicalForm("234567"))
    }

    @Test func isCanonicalFormRejectsLowercase() {
        // `init?(_:)` would uppercase and accept; `isCanonicalForm`
        // is strict — its caller (the router) uppercases first.
        #expect(PairCode.isCanonicalForm("abc234") == false)
    }

    @Test func isCanonicalFormRejectsSeparators() {
        // `init?(_:)` strips dashes/spaces; `isCanonicalForm` does
        // not — deep-link wire format is 6 chars with no
        // punctuation.
        #expect(PairCode.isCanonicalForm("ABC-234") == false)
        #expect(PairCode.isCanonicalForm("ABC 234") == false)
    }

    @Test func isCanonicalFormRejectsAmbiguousGlyphs() {
        // 0 / 1 / I / O are deliberately excluded from the alphabet.
        #expect(PairCode.isCanonicalForm("ABC0IO") == false)
        #expect(PairCode.isCanonicalForm("AB10IO") == false)
    }

    @Test func isCanonicalFormRejectsWrongLength() {
        #expect(PairCode.isCanonicalForm("ABC23") == false)
        #expect(PairCode.isCanonicalForm("ABC2345") == false)
        #expect(PairCode.isCanonicalForm("") == false)
    }

    @Test func canonicalAlphabetMatchesContract() {
        // Byte-for-byte parity guard. If this ever drifts, the
        // equivalent backend regex in `firestore.rules` and
        // `pair.html` will also need to change in lockstep.
        #expect(
            PairCode.canonicalAlphabet
                == "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        )
    }
}

@MainActor
struct PairingViewModelTests {
    @Test func startsUnpaired() {
        let viewModel = PairingViewModel()
        #expect(viewModel.pairingState == .unpaired)
        #expect(viewModel.codeInput.isEmpty)
        #expect(viewModel.codeInputIsInvalid == false)
    }

    @Test func generateCodeMovesToWaiting() async {
        let service = MockPairingService(simulatedDelay: .seconds(60))
        let viewModel = PairingViewModel(pairingService: service)

        await viewModel.generateCode()

        if case .waitingForPartner(let code) = viewModel.pairingState {
            #expect(code.value.count == PairCode.length)
        } else {
            Issue.record("Expected waitingForPartner state")
        }
    }

    @Test func cancelWaitingReturnsToUnpaired() async {
        let service = MockPairingService(simulatedDelay: .seconds(60))
        let viewModel = PairingViewModel(pairingService: service)

        await viewModel.generateCode()
        viewModel.cancelWaiting()

        #expect(viewModel.pairingState == .unpaired)
    }

    @Test func joinWithValidCodePairsSuccessfully() async {
        let partner = PartnerProfile(
            id: "test-id",
            displayName: "Alice",
            pairedAt: .now
        )
        let service = MockPairingService(
            simulatedDelay: .milliseconds(50),
            simulatedPartner: partner
        )
        let viewModel = PairingViewModel(pairingService: service)

        viewModel.codeInput = "ABC234"
        await viewModel.joinWithEnteredCode()

        if case .paired(let result) = viewModel.pairingState {
            #expect(result.displayName == "Alice")
        } else {
            Issue.record("Expected paired state")
        }
    }

    @Test func joinWithInvalidCodeSetsValidationFlag() async {
        let viewModel = PairingViewModel()

        viewModel.codeInput = "AB"
        await viewModel.joinWithEnteredCode()

        #expect(viewModel.codeInputIsInvalid)
    }

    @Test func unpairReturnsToUnpaired() async {
        let partner = PartnerProfile(
            id: "test-id",
            displayName: "Bob",
            pairedAt: .now
        )
        let service = MockPairingService(
            simulatedDelay: .milliseconds(10),
            simulatedPartner: partner
        )
        let viewModel = PairingViewModel(pairingService: service)

        viewModel.codeInput = "ABC234"
        await viewModel.joinWithEnteredCode()

        await viewModel.unpair()

        #expect(viewModel.pairingState == .unpaired)
        #expect(viewModel.codeInput.isEmpty)
    }

    @Test func checkExistingPairingDefaultsToUnpaired() async {
        let service = MockPairingService()
        let viewModel = PairingViewModel(pairingService: service)

        await viewModel.checkExistingPairing()

        #expect(viewModel.pairingState == .unpaired)
    }
}
