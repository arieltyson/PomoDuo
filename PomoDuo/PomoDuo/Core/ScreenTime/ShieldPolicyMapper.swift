import FamilyControls
import ManagedSettings

/// Translates a ``FamilyActivitySelection`` into the `ManagedSettingsStore.shield`
/// writes that enforce it.
///
/// Lives in its own type (rather than inline inside
/// ``ManagedSettingsRestrictionService``) because both the main app and
/// ``DeviceActivityMonitorExtension`` must apply **exactly** the same
/// interpretation of the selection — if the first enforcement and the
/// extension's re-application under force-quit disagreed, the Shield would
/// flicker between policies.
///
/// ### Selection semantics (per Apple's docs)
///
/// A `FamilyActivitySelection` is **inclusive**. Every token it holds
/// represents something the user *picked to block*:
///
/// - `categoryTokens` — activity categories the user selected.
/// - `applicationTokens` — individual applications the user selected (and,
///   when `includeEntireCategory` is `true`, applications enumerated from
///   the selected categories).
/// - `webDomainTokens` — web domains the user selected (and, under
///   `includeEntireCategory: true`, domains enumerated from selected
///   categories).
///
/// Apple's own descriptions:
///
/// > Tokens that represent applications selected by the user.
/// > …represents categories selected by the user.
/// > …represents web domains selected by the user.
/// > `includeEntireCategory` — whether the selection should include
/// > applications and web domains *from* the selected categories.
///
/// The `except:` associated value on
/// `ShieldSettings.ActivityCategoryPolicy.all(except:)` and
/// `.specific(_:except:)` is an *entirely separate* Screen Time concept —
/// it exempts specific application or web-domain tokens from a
/// category-wide shield. It is not related to what the picker returns.
///
/// ### How the shield writes map to this selection
///
/// - When the user picked one or more categories, write
///   `store.shield.applicationCategories = .specific(categoryTokens)` and
///   `store.shield.webDomainCategories = .specific(categoryTokens)` so
///   every app and every web domain in those categories gets shielded by
///   the system — including items the picker did not enumerate into the
///   selection.
/// - When the user picked individual application tokens, additionally
///   write `store.shield.applications = applicationTokens` so any app that
///   lives outside the selected categories (or that belongs to no
///   category) is still shielded.
/// - Same for `store.shield.webDomains = webDomainTokens`.
///
/// ### What changed from the previous mapper
///
/// The old mapper treated `applicationTokens` as *exceptions* carved out
/// of `.all(except:)` or `.specific(_:except:)`. That was the inverse of
/// the product's intent: the 97 apps the user picked to block were being
/// exempted from the shield, so blocked apps kept launching. The root
/// cause was a misreading of Apple's docs and was reinforced by tests that
/// codified the wrong shape. Removing the exception-based cases and the
/// 12-category threshold heuristic collapses the mapping to a small,
/// correct, documentation-supported shape.
enum ShieldPolicyMapper {

    /// Application-side category policy derived from a selection.
    ///
    /// `.specific(_)` is the only inclusive case — `.none` means no
    /// category-level shield is written. The exception-based shapes from
    /// the prior implementation (`.allExcept`, `.specificExcept`) were
    /// deleted because the product never wanted an exception semantic.
    enum ApplicationCategoryPolicy: Equatable {
        case none
        case specific(Set<ActivityCategoryToken>)
    }

    /// Web-domain-side category policy derived from a selection.
    enum WebDomainCategoryPolicy: Equatable {
        case none
        case specific(Set<ActivityCategoryToken>)
    }

    /// The full shield-writing plan.
    struct Decision: Equatable {
        let applicationCategories: ApplicationCategoryPolicy
        let webDomainCategories: WebDomainCategoryPolicy
        /// Apps shielded via the specific-apps channel (`store.shield.applications`).
        /// `nil` means don't write that channel — there are no individual
        /// apps to shield in addition to the category policy.
        let specificApplications: Set<ApplicationToken>?
        /// Web domains shielded via `store.shield.webDomains`.
        let specificWebDomains: Set<WebDomainToken>?
    }

    /// Computes the shield-writing plan for a given selection.
    ///
    /// The mapping is a straight inclusive read of the selection — no
    /// thresholds, no exception carve-outs, no mode detection. Every token
    /// in the selection is something the user wants blocked; every token
    /// outside the selection is something they don't.
    static func decide(
        applicationTokens: Set<ApplicationToken>,
        categoryTokens: Set<ActivityCategoryToken>,
        webDomainTokens: Set<WebDomainToken>
    ) -> Decision {
        let applicationCategories: ApplicationCategoryPolicy =
            categoryTokens.isEmpty ? .none : .specific(categoryTokens)

        let webDomainCategories: WebDomainCategoryPolicy =
            categoryTokens.isEmpty ? .none : .specific(categoryTokens)

        return Decision(
            applicationCategories: applicationCategories,
            webDomainCategories: webDomainCategories,
            specificApplications: applicationTokens.isEmpty
                ? nil : applicationTokens,
            specificWebDomains: webDomainTokens.isEmpty ? nil : webDomainTokens
        )
    }

    /// Convenience for `FamilyActivitySelection` callers.
    static func decide(
        for selection: FamilyActivitySelection
    ) -> Decision {
        decide(
            applicationTokens: selection.applicationTokens,
            categoryTokens: selection.categoryTokens,
            webDomainTokens: selection.webDomainTokens
        )
    }

    /// Case-only shape of the decision, independent of opaque token values.
    ///
    /// Exposed so tests can verify the mapping semantics without having to
    /// construct real Screen Time tokens — those are system-issued and
    /// can't be fabricated inside a unit test. The case enumeration is
    /// exactly what determines which `ManagedSettings` channel is written.
    enum ApplicationPolicyCase: Equatable {
        case none
        case specific
    }

    enum WebDomainPolicyCase: Equatable {
        case none
        case specific
    }

    struct DecisionShape: Equatable {
        let applicationCategories: ApplicationPolicyCase
        let webDomainCategories: WebDomainPolicyCase
        /// Whether `store.shield.applications` gets written with the
        /// selection's `applicationTokens`.
        let writesSpecificApplicationsChannel: Bool
        /// Whether `store.shield.webDomains` gets written with the
        /// selection's `webDomainTokens`.
        let writesSpecificWebDomainsChannel: Bool
    }

    /// Pure, count-driven mapping that tests can drive with plain `Int`s.
    ///
    /// Matches ``decide(applicationTokens:categoryTokens:webDomainTokens:)``
    /// step-for-step so the two stay in lockstep.
    static func decideShape(
        applicationTokenCount: Int,
        categoryTokenCount: Int,
        webDomainTokenCount: Int
    ) -> DecisionShape {
        let applicationCategories: ApplicationPolicyCase =
            categoryTokenCount == 0 ? .none : .specific

        let webDomainCategories: WebDomainPolicyCase =
            categoryTokenCount == 0 ? .none : .specific

        return DecisionShape(
            applicationCategories: applicationCategories,
            webDomainCategories: webDomainCategories,
            writesSpecificApplicationsChannel: applicationTokenCount > 0,
            writesSpecificWebDomainsChannel: webDomainTokenCount > 0
        )
    }

    /// Writes a ``Decision`` into a `ManagedSettingsStore`'s shield.
    ///
    /// Centralizing the apply step here guarantees the main app and the
    /// Monitor extension perform the exact same writes for the same
    /// decision.
    static func apply(_ decision: Decision, to store: ManagedSettingsStore) {
        switch decision.applicationCategories {
        case .none:
            store.shield.applicationCategories = nil
        case .specific(let categories):
            store.shield.applicationCategories = .specific(categories)
        }

        switch decision.webDomainCategories {
        case .none:
            store.shield.webDomainCategories = nil
        case .specific(let categories):
            store.shield.webDomainCategories = .specific(categories)
        }

        store.shield.applications = decision.specificApplications
        store.shield.webDomains = decision.specificWebDomains
    }
}
