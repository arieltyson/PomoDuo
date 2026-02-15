//
//  PairingTests.swift
//  PomoDuoTests
//
//  Created by Codex on 2/15/26.
//

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

        if case let .waitingForPartner(code) = viewModel.pairingState {
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
        let partner = PartnerProfile(id: "test-id", displayName: "Alice", pairedAt: .now)
        let service = MockPairingService(simulatedDelay: .milliseconds(50), simulatedPartner: partner)
        let viewModel = PairingViewModel(pairingService: service)

        viewModel.codeInput = "ABC234"
        await viewModel.joinWithEnteredCode()

        if case let .paired(result) = viewModel.pairingState {
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
        let partner = PartnerProfile(id: "test-id", displayName: "Bob", pairedAt: .now)
        let service = MockPairingService(simulatedDelay: .milliseconds(10), simulatedPartner: partner)
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
