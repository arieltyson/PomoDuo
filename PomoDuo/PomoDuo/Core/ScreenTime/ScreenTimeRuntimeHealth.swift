import Foundation

/// App-side classification of the Screen Time pipeline's runtime health.
///
/// Derived purely from a ``ScreenTimeDiagnostics`` snapshot — never claims
/// OS-confirmed effective shielding, because Apple does not expose that.
/// The classification answers two questions truthfully:
///
/// 1. From the app's perspective, is everything in place that *should* be
///    in place for app blocking to work right now?
/// 2. If something is missing, is it something the app can repair on its
///    own (degraded), or is it a precondition the user has to fix
///    (unavailable)?
///
/// The active-session UI uses this to show chip copy that matches what the
/// app can honestly know, and the focus-session entry/foreground hooks use
/// it as the trigger for a full-pipeline reconcile.
enum ScreenTimeRuntimeHealth: Equatable, Sendable {

    /// All app-side preconditions and runtime channels look correct for
    /// the current focus-session intent.
    case healthy

    /// Configuration is fine but the runtime pipeline has gaps the app
    /// can repair without user action (missing schedule, missing context,
    /// stale shield channels, etc.).
    case degraded(reasons: Set<DegradationReason>)

    /// A precondition outside the runtime pipeline is missing — Screen Time
    /// is not authorized, the user has no selection, or the computed
    /// policy would shield nothing. The user has to act before app
    /// blocking can do anything meaningful.
    case unavailable(reason: UnavailableReason)

    enum DegradationReason: String, Sendable, Hashable, CaseIterable {
        /// `DeviceActivityCenter.activities` does not contain the focus
        /// activity even though the app expects an active focus session.
        case missingDeviceActivityRegistration
        /// `ShieldSessionContext.isSessionActive` is `false` even though
        /// the app expects an active focus session.
        case missingSharedSessionContext
        /// One or more `ManagedSettingsStore.shield` channels that the
        /// computed policy says should be configured aren't configured.
        case shieldChannelsNotConfigured
        /// The in-memory selection lost its `includeEntireCategory: true`
        /// flag and would fall back to lossy semantics on the next edit.
        case selectionNotCanonical
    }

    enum UnavailableReason: String, Sendable, Hashable, CaseIterable {
        case authorizationNotUsable
        case selectionEmpty
        case computedPolicyShieldsNothing
    }

    /// `true` for ``healthy`` and ``degraded`` (the app believes its
    /// blocking pipeline is *requested*); `false` for ``unavailable``.
    var isRequestable: Bool {
        switch self {
        case .healthy, .degraded:
            true
        case .unavailable:
            false
        }
    }

    /// `true` only for ``degraded`` — used by reconcile call sites to
    /// decide whether a full-pipeline rewrite would be useful right now.
    /// (Reconcile is always *safe* to call; this is just the "should we?"
    /// hint.)
    var canBeRepaired: Bool {
        if case .degraded = self { return true }
        return false
    }

    // MARK: - Evaluation

    /// Classifies a diagnostics snapshot against the caller's understanding
    /// of whether a focus session is currently expected to be active.
    ///
    /// Outside an active focus session, the runtime channels are
    /// *expected* to be empty, so missing schedule/context/shield writes
    /// don't count as degradation.
    static func evaluate(
        snapshot: ScreenTimeDiagnostics,
        focusIsActive: Bool
    ) -> ScreenTimeRuntimeHealth {
        // Unavailable preconditions short-circuit everything else: there
        // is nothing repairable about them at the runtime layer.
        guard snapshot.authorization.isUsable else {
            return .unavailable(reason: .authorizationNotUsable)
        }
        let hasAnySelection =
            snapshot.selection.applicationCount
            + snapshot.selection.categoryCount
            + snapshot.selection.webDomainCount > 0
        guard hasAnySelection else {
            return .unavailable(reason: .selectionEmpty)
        }
        let policy = snapshot.policy
        let policyHasAnyChannel =
            policy.applicationCategories != .none
            || policy.webDomainCategories != .none
            || policy.writesSpecificApplicationsChannel
            || policy.writesSpecificWebDomainsChannel
        guard policyHasAnyChannel else {
            return .unavailable(reason: .computedPolicyShieldsNothing)
        }

        var reasons: Set<DegradationReason> = []

        if !snapshot.selection.isCanonical {
            reasons.insert(.selectionNotCanonical)
        }

        if focusIsActive {
            // Compare what the policy says we *should* have configured
            // against what the snapshot reports as actually configured.
            let appCategoriesExpected =
                policy.applicationCategories != .none
            let appsChannelExpected = policy.writesSpecificApplicationsChannel
            let webCategoriesExpected = policy.webDomainCategories != .none
            let webChannelExpected = policy.writesSpecificWebDomainsChannel

            let appCategoriesMissing =
                appCategoriesExpected
                && !snapshot.shieldChannels.applicationCategoriesConfigured
            let appsChannelMissing =
                appsChannelExpected
                && !snapshot.shieldChannels.applicationsConfigured
            let webCategoriesMissing =
                webCategoriesExpected
                && !snapshot.shieldChannels.webDomainCategoriesConfigured
            let webChannelMissing =
                webChannelExpected
                && !snapshot.shieldChannels.webDomainsConfigured

            if appCategoriesMissing || appsChannelMissing
                || webCategoriesMissing || webChannelMissing
            {
                reasons.insert(.shieldChannelsNotConfigured)
            }

            if !snapshot.monitoring.focusActivityRegistered {
                reasons.insert(.missingDeviceActivityRegistration)
            }
            if !snapshot.sessionContext.isActive {
                reasons.insert(.missingSharedSessionContext)
            }
        }

        return reasons.isEmpty ? .healthy : .degraded(reasons: reasons)
    }
}
