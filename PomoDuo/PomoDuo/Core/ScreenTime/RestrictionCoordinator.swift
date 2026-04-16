import Foundation
import ManagedSettings
import Observation

/// Writes shared session context used by the Shield and Monitor extensions.
///
/// Production uses ``DefaultFocusSessionContextWriter`` (which forwards to
/// ``ShieldSessionContext``). Tests inject a spy so coordinator behavior
/// is verifiable without races on the App Group `UserDefaults`.
@MainActor
protocol FocusSessionContextWriting: Sendable {
    func writeFocus(targetEndDate: Date)
    func clearFocus()
}

@MainActor
struct DefaultFocusSessionContextWriter: FocusSessionContextWriting {
    func writeFocus(targetEndDate: Date) {
        ShieldSessionContext.writeSession(
            partnerName: nil,
            phase: "Focus",
            targetEndDate: targetEndDate
        )
    }

    func clearFocus() {
        ShieldSessionContext.clearSession()
    }
}

/// Coordinates the full Family Controls enforcement pipeline for a focus
/// session: ManagedSettings shields, shared App Group session context, and
/// DeviceActivity monitoring.
///
/// The timer calls this coordinator on focus/break/stop transitions so view
/// code stays synchronous and does not need `try await` plumbing. All
/// operations are serialized through `pendingTask` to prevent race conditions
/// when start/stop happen in quick succession.
///
/// - Note: Driving all three pieces (shields + context + monitoring) from a
///   single owner is what lets the ``DeviceActivityMonitorExtension`` re-apply
///   shields independently of the app process. The bare main-app shield write
///   alone is not reliable enough on iOS 26 to keep apps blocked across
///   foregrounding, intent invocations, and extension callbacks.
@MainActor
@Observable
final class RestrictionCoordinator {
    /// Whether restrictions are currently active for the running session.
    private(set) var isRestricting = false

    /// The most recent service error, useful for diagnostics.
    private(set) var lastError: (any Error)?

    private let restrictionService: any RestrictionService
    private let focusScheduler: FocusActivityScheduler?
    private let sessionContextWriter: any FocusSessionContextWriting
    private let canRestrictEvaluator: @MainActor () -> Bool

    /// Serializes apply/remove calls so a late-arriving apply
    /// can never overwrite an earlier remove.
    private var pendingTask: Task<Void, Never>?

    init(
        screenTimeManager: ScreenTimeManager,
        restrictionService: (any RestrictionService)? = nil,
        managedSettingsStore: ManagedSettingsStore? = nil,
        focusScheduler: FocusActivityScheduler? = nil,
        sessionContextWriter: (any FocusSessionContextWriting)? = nil,
        canRestrictEvaluator: (@MainActor () -> Bool)? = nil
    ) {
        if let restrictionService {
            self.restrictionService = restrictionService
        } else {
            let resolvedStore = managedSettingsStore ?? ManagedSettingsStore()
            self.restrictionService = ManagedSettingsRestrictionService(
                screenTimeManager: screenTimeManager,
                store: resolvedStore
            )
        }

        self.focusScheduler = focusScheduler
        self.sessionContextWriter =
            sessionContextWriter ?? DefaultFocusSessionContextWriter()
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

    /// Applies shields, writes shared session context, and schedules
    /// DeviceActivity monitoring up to `endDate`.
    ///
    /// The monitoring schedule lets ``DeviceActivityMonitorExtension``
    /// re-apply shields from a separate process at `intervalDidStart` and
    /// remove them at `intervalDidEnd`, which is what keeps blocked apps
    /// actually blocked when the main app is backgrounded or killed.
    func enforceFocusRestrictions(until endDate: Date) {
        guard !isRestricting, canRestrict else { return }

        let scheduler = focusScheduler
        let contextWriter = sessionContextWriter
        enqueue { [restrictionService] in
            try await restrictionService.applyRestrictions()
            contextWriter.writeFocus(targetEndDate: endDate)
            scheduler?.scheduleMonitoring(until: endDate)
            return true
        }
    }

    /// Lifts shields for break and completion phases, stops DeviceActivity
    /// monitoring, and clears shared session context.
    ///
    /// All three steps run together so a stale schedule cannot fire
    /// `intervalDidStart` against an already-finished session and re-apply
    /// shields under the user.
    func liftRestrictions() {
        guard isRestricting else { return }

        let scheduler = focusScheduler
        let contextWriter = sessionContextWriter
        enqueue { [restrictionService] in
            try await restrictionService.removeRestrictions()
            scheduler?.stopMonitoring()
            contextWriter.clearFocus()
            return false
        }
    }

    /// Safety-net teardown used when the user explicitly stops the timer.
    ///
    /// Always cancels monitoring and clears session context — even on a
    /// shield-removal error — so the Monitor extension cannot reassert
    /// shields after a manual stop.
    func forceRemoveRestrictions() {
        let scheduler = focusScheduler
        let contextWriter = sessionContextWriter
        enqueue { [restrictionService] in
            defer {
                scheduler?.stopMonitoring()
                contextWriter.clearFocus()
            }
            try await restrictionService.removeRestrictions()
            return false
        }
    }

    /// Re-applies the latest app/category selection while restrictions are
    /// active. Use this after ``ScreenTimeManager/activitySelection`` changes
    /// mid-session.
    ///
    /// If the user cleared all selections (emergency unblock), this performs
    /// a full pipeline teardown.
    func refreshRestrictions() {
        guard isRestricting else { return }

        if canRestrict {
            enqueue { [restrictionService] in
                try await restrictionService.applyRestrictions()
                return true
            }
        } else {
            let scheduler = focusScheduler
            let contextWriter = sessionContextWriter
            enqueue { [restrictionService] in
                try await restrictionService.removeRestrictions()
                scheduler?.stopMonitoring()
                contextWriter.clearFocus()
                return false
            }
        }
    }

    // MARK: - Private

    /// Cancels any in-flight operation, then runs the new one.
    /// The closure returns the desired `isRestricting` value on success.
    ///
    /// The operation closure is `@MainActor`-isolated so it can call the
    /// synchronous `@MainActor` APIs on ``FocusActivityScheduler`` and
    /// ``ShieldSessionContext`` directly without an extra actor hop.
    private func enqueue(
        operation: @escaping @MainActor @Sendable () async throws -> Bool
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
