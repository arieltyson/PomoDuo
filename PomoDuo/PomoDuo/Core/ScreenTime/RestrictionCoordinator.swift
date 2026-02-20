import Observation

/// Coordinates restriction enforcement for the solo timer lifecycle.
///
/// The timer calls this coordinator on focus/break/stop transitions
/// so view code stays synchronous and does not need `try await` plumbing.
///
/// All operations are serialized through `pendingTask` to prevent
/// race conditions when start/stop happen in quick succession.
@MainActor
@Observable
final class RestrictionCoordinator {
    /// Whether restrictions are currently active for the running session.
    private(set) var isRestricting = false

    /// The most recent service error, useful for diagnostics.
    private(set) var lastError: (any Error)?

    private let restrictionService: any RestrictionService
    private let canRestrictEvaluator: @MainActor () -> Bool

    /// Serializes apply/remove calls so a late-arriving apply
    /// can never overwrite an earlier remove.
    private var pendingTask: Task<Void, Never>?

    init(
        screenTimeManager: ScreenTimeManager,
        restrictionService: (any RestrictionService)? = nil,
        canRestrictEvaluator: (@MainActor () -> Bool)? = nil
    ) {
        self.restrictionService =
            restrictionService
            ?? ManagedSettingsRestrictionService(
                screenTimeManager: screenTimeManager
            )

        self.canRestrictEvaluator =
            canRestrictEvaluator ?? { [weak screenTimeManager] in
                guard let screenTimeManager else { return false }
                return screenTimeManager.isAuthorized
                    && screenTimeManager.hasSelectedApps
            }
    }

    /// Whether restrictions can currently be enforced.
    var canRestrict: Bool {
        canRestrictEvaluator()
    }

    /// Applies restrictions for focus phases.
    func enforceFocusRestrictions() {
        guard !isRestricting, canRestrict else { return }

        enqueue { [restrictionService] in
            try await restrictionService.applyRestrictions()
            return true
        }
    }

    /// Lifts restrictions for break and completion phases.
    func liftRestrictions() {
        guard isRestricting else { return }

        enqueue { [restrictionService] in
            try await restrictionService.removeRestrictions()
            return false
        }
    }

    /// Safety-net removal used when the user explicitly stops the timer.
    func forceRemoveRestrictions() {
        enqueue { [restrictionService] in
            try await restrictionService.removeRestrictions()
            return false
        }
    }

    /// Re-applies the latest app/category selection while restrictions are active.
    ///
    /// Use this after `ScreenTimeManager.activitySelection` changes mid-session.
    /// No-op when restrictions are not currently active.
    func refreshRestrictions() {
        guard isRestricting else { return }

        enqueue { [restrictionService] in
            try await restrictionService.applyRestrictions()
            return true
        }
    }

    // MARK: - Private

    /// Cancels any in-flight operation, then runs the new one.
    /// The closure returns the desired `isRestricting` value on success.
    private func enqueue(
        operation: @escaping @Sendable () async throws -> Bool
    ) {
        pendingTask?.cancel()

        pendingTask = Task { @MainActor in
            do {
                let restricting = try await operation()
                guard !Task.isCancelled else { return }
                isRestricting = restricting
                lastError = nil
            } catch is CancellationError {
                // Operation was superseded — ignore.
            } catch {
                guard !Task.isCancelled else { return }
                lastError = error
            }
        }
    }
}
