//
//  PairingViewModel.swift
//  PomoDuo
//
//  Created by Codex on 2/15/26.
//

import Foundation
import Observation

/// Observable state and intents for the partner pairing flow.
@MainActor
@Observable
final class PairingViewModel {
    /// The current lifecycle state of pairing.
    private(set) var pairingState: PairingState = .unpaired

    /// Raw text entered in the partner code sheet.
    var codeInput = ""

    /// Set to `true` when the entered code fails validation.
    var codeInputIsInvalid = false

    private let pairingService: any PairingService
    private var waitTask: Task<Void, Never>?

    init(pairingService: any PairingService = MockPairingService()) {
        self.pairingService = pairingService
    }

    /// Restores an existing pairing if the backend has one.
    func checkExistingPairing() async {
        do {
            if let partner = try await pairingService.currentPartner() {
                pairingState = .paired(partner)
                return
            }

            pairingState = .unpaired
        } catch {
            pairingState = .unpaired
        }
    }

    /// Generates and publishes a pairing code, then listens for joins.
    func generateCode() async {
        codeInputIsInvalid = false

        let code = PairCode.generate()

        do {
            let isPublished = try await pairingService.publishCode(code)
            guard isPublished else {
                pairingState = .error("Unable to publish a pairing code right now.")
                return
            }

            pairingState = .waitingForPartner(code: code)
            waitForPartner(using: code)
        } catch {
            pairingState = .error("Unable to start pairing. Please try again.")
        }
    }

    /// Exits the waiting state and returns to unpaired.
    func cancelWaiting() {
        waitTask?.cancel()
        waitTask = nil
        pairingState = .unpaired
    }

    /// Validates and joins with the entered partner code.
    func joinWithEnteredCode() async {
        guard let code = PairCode(codeInput) else {
            codeInputIsInvalid = true
            return
        }

        codeInputIsInvalid = false
        pairingState = .joining

        do {
            if let partner = try await pairingService.joinWithCode(code) {
                codeInput = ""
                pairingState = .paired(partner)
            } else {
                pairingState = .error("No partner was found with that code.")
            }
        } catch {
            pairingState = .error("Could not connect right now. Please try again.")
        }
    }

    /// Disconnects the current partner and returns to unpaired.
    func unpair() async {
        waitTask?.cancel()
        waitTask = nil

        do {
            try await pairingService.unpair()
        } catch {
            // Pairing cleanup is best effort.
        }

        pairingState = .unpaired
        codeInput = ""
        codeInputIsInvalid = false
    }

    /// Dismisses the current error and returns to unpaired.
    func dismissError() {
        pairingState = .unpaired
    }

    /// Clears local pairing UI state without performing remote mutations.
    ///
    /// Used when auth identity changes or signs out, so stale pairing data
    /// does not leak into the next account session.
    func resetForSignedOut() {
        waitTask?.cancel()
        waitTask = nil
        pairingState = .unpaired
        codeInput = ""
        codeInputIsInvalid = false
    }

    private func waitForPartner(using code: PairCode) {
        waitTask?.cancel()

        waitTask = Task { [weak self] in
            guard let self else {
                return
            }

            for await partner in pairingService.waitForPartner(code: code) {
                guard !Task.isCancelled else {
                    return
                }

                pairingState = .paired(partner)
                waitTask = nil
                return
            }
        }
    }
}
