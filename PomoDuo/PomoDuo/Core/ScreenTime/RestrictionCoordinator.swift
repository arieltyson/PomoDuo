//
//  RestrictionCoordinator.swift
//  PomoDuo
//
//  Created by Codex on 2/15/26.
//

import Observation

/// Coordinates restriction enforcement for the solo timer lifecycle.
///
/// The timer calls this coordinator on focus/break/stop transitions
/// so view code stays synchronous and does not need `try await` plumbing.
@MainActor
@Observable
final class RestrictionCoordinator {
    /// Whether restrictions are currently active for the running session.
    private(set) var isRestricting = false

    /// The most recent service error, useful for diagnostics.
    private(set) var lastError: (any Error)?

    private let restrictionService: any RestrictionService
    private let canRestrictEvaluator: @MainActor () -> Bool

    init(
        screenTimeManager: ScreenTimeManager,
        restrictionService: (any RestrictionService)? = nil,
        canRestrictEvaluator: (@MainActor () -> Bool)? = nil
    ) {
        self.restrictionService = restrictionService
            ?? ManagedSettingsRestrictionService(screenTimeManager: screenTimeManager)

        self.canRestrictEvaluator = canRestrictEvaluator ?? { [weak screenTimeManager] in
            guard let screenTimeManager else { return false }
            return screenTimeManager.isAuthorized && screenTimeManager.hasSelectedApps
        }
    }

    /// Whether restrictions can currently be enforced.
    var canRestrict: Bool {
        canRestrictEvaluator()
    }

    /// Applies restrictions for focus phases.
    func enforceFocusRestrictions() {
        guard !isRestricting, canRestrict else { return }

        Task { @MainActor in
            do {
                try await restrictionService.applyRestrictions()
                isRestricting = true
                lastError = nil
            } catch {
                lastError = error
            }
        }
    }

    /// Lifts restrictions for break and completion phases.
    func liftRestrictions() {
        guard isRestricting else { return }

        Task { @MainActor in
            do {
                try await restrictionService.removeRestrictions()
                isRestricting = false
                lastError = nil
            } catch {
                lastError = error
            }
        }
    }

    /// Safety-net removal used when the user explicitly stops the timer.
    func forceRemoveRestrictions() {
        Task { @MainActor in
            do {
                try await restrictionService.removeRestrictions()
                lastError = nil
            } catch {
                lastError = error
            }

            isRestricting = false
        }
    }
}
