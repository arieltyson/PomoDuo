import FamilyControls
import Foundation

/// Honest, app-side snapshot of every Screen Time piece PomoDuo has configured
/// or knows about.
///
/// **What this snapshot is — and is not.**
/// Apple's `ManagedSettingsStore`, `DeviceActivityCenter`, and `AuthorizationCenter`
/// expose what the *app* has configured and what schedules the system has
/// *registered*. None of them expose whether iOS is actually shielding apps
/// at this exact moment — that's the operating system's responsibility, not
/// the app's. So this snapshot is intentionally framed as "what the app
/// configured / requested / restored", never "what the OS is currently
/// enforcing".
///
/// All fields are `Equatable` and `Sendable` so the snapshot can be diffed,
/// rendered, and (in tests) round-tripped without surprises.
struct ScreenTimeDiagnostics: Equatable, Sendable {
    let authorization: Authorization
    let selection: Selection
    let policy: ShieldPolicyMapper.DecisionShape
    let shieldChannels: ShieldChannels
    let monitoring: Monitoring
    let sessionContext: SessionContext
    let capturedAt: Date

    struct Authorization: Equatable, Sendable {
        let status: AuthorizationStatus
        /// Whether the current authorization status is one PomoDuo treats
        /// as usable (`.approved` on iOS 26 and below, also
        /// `.approvedWithDataAccess` on iOS 26.4+).
        let isUsable: Bool
    }

    struct Selection: Equatable, Sendable {
        let applicationCount: Int
        let categoryCount: Int
        let webDomainCount: Int
        /// Whether the in-memory selection still carries
        /// `includeEntireCategory: true` — the canonical form
        /// ``ShieldPolicyMapper`` expects.
        let isCanonical: Bool
    }

    struct ShieldChannels: Equatable, Sendable {
        let applicationsConfigured: Bool
        let applicationsCount: Int
        let applicationCategoriesConfigured: Bool
        let webDomainsConfigured: Bool
        let webDomainsCount: Int
        let webDomainCategoriesConfigured: Bool
    }

    struct Monitoring: Equatable, Sendable {
        let focusActivityRegistered: Bool
        /// The end of the registered focus activity's interval, if
        /// reconstructable from the schedule's `DateComponents`.
        let focusScheduleEnd: Date?
    }

    struct SessionContext: Equatable, Sendable {
        let isActive: Bool
        let phase: String?
        let targetEndDate: Date?
    }
}
