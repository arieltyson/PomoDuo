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
/// ### Why this exists
///
/// `FamilyActivitySelection.applicationTokens` carries two different
/// semantics depending on how the picker was used:
///
/// - When the user picked "All Apps & Categories" and then deselected a
///   handful of specific apps, those deselected apps end up in
///   `applicationTokens` as **exceptions**. The policy must then be
///   `.all(except: applicationTokens)` — a naive `.all(except: [])` would
///   keep them blocked, and a naive `.specific(categoryTokens)` would miss
///   uncategorized apps entirely.
/// - When the user picked specific categories (fewer than all) alongside
///   extra individual apps, those individual apps are **inclusions**: they
///   should be shielded in addition to the selected categories, via
///   `store.shield.applications = applicationTokens`.
///
/// Relying solely on `categoryTokens.count >= threshold` without also
/// threading `applicationTokens` through the policy's `except:` parameter
/// was the root cause of the "remove some apps, lose more apps than
/// expected" bug: dropping from `.all(except: [])` to
/// `.specific(N-1 categories)` silently stopped shielding every uncategorized
/// app and every app in the dropped category that the picker hadn't
/// enumerated.
enum ShieldPolicyMapper {

    /// Application-side category policy derived from a selection.
    enum ApplicationCategoryPolicy: Equatable {
        case none
        case allExcept(Set<ApplicationToken>)
        case specific(Set<ActivityCategoryToken>)
    }

    /// Web-domain-side category policy derived from a selection.
    enum WebDomainCategoryPolicy: Equatable {
        case none
        case all
        case specific(Set<ActivityCategoryToken>)
    }

    /// The full shield-writing plan.
    struct Decision: Equatable {
        let applicationCategories: ApplicationCategoryPolicy
        let webDomainCategories: WebDomainCategoryPolicy
        /// Apps shielded via the specific-apps channel (`store.shield.applications`).
        /// `nil` means don't write that channel — either there are no extra
        /// apps to shield beyond the category policy, or those apps are
        /// already represented as exceptions inside `applicationCategories`.
        let specificApplications: Set<ApplicationToken>?
        /// Web domains shielded via `store.shield.webDomains`.
        let specificWebDomains: Set<WebDomainToken>?
    }

    /// Computes the shield-writing plan for a given selection.
    ///
    /// - Parameters:
    ///   - applicationTokens: The selection's `applicationTokens`.
    ///   - categoryTokens: The selection's `categoryTokens`.
    ///   - webDomainTokens: The selection's `webDomainTokens`.
    ///   - allCategoriesThreshold: How many category tokens count as the
    ///     "All Apps & Categories" pick. Compared with `>=`.
    static func decide(
        applicationTokens: Set<ApplicationToken>,
        categoryTokens: Set<ActivityCategoryToken>,
        webDomainTokens: Set<WebDomainToken>,
        allCategoriesThreshold: Int
    ) -> Decision {
        let hasAllCategories = categoryTokens.count >= allCategoriesThreshold
        let hasAnyCategory = !categoryTokens.isEmpty
        let hasApps = !applicationTokens.isEmpty
        let hasWebDomains = !webDomainTokens.isEmpty

        let applicationCategories: ApplicationCategoryPolicy
        let specificApplications: Set<ApplicationToken>?

        if hasAllCategories {
            // "All Apps & Categories" workflow. `applicationTokens` are
            // exceptions — apps the user deselected after picking all. They
            // must not be shielded, so they can't flow through the
            // specific-apps channel either.
            applicationCategories = .allExcept(applicationTokens)
            specificApplications = nil
        } else if hasAnyCategory {
            // Some categories + optional additional specific apps.
            // `applicationTokens` are inclusions in this mode — extra apps
            // to shield alongside the selected categories.
            applicationCategories = .specific(categoryTokens)
            specificApplications = hasApps ? applicationTokens : nil
        } else {
            // Only specific apps (or nothing at all).
            applicationCategories = .none
            specificApplications = hasApps ? applicationTokens : nil
        }

        let webDomainCategories: WebDomainCategoryPolicy
        if hasAllCategories {
            webDomainCategories = .all
        } else if hasAnyCategory {
            webDomainCategories = .specific(categoryTokens)
        } else {
            webDomainCategories = .none
        }

        return Decision(
            applicationCategories: applicationCategories,
            webDomainCategories: webDomainCategories,
            specificApplications: specificApplications,
            specificWebDomains: hasWebDomains ? webDomainTokens : nil
        )
    }

    /// Convenience for `FamilyActivitySelection` callers.
    static func decide(
        for selection: FamilyActivitySelection,
        allCategoriesThreshold: Int
    ) -> Decision {
        decide(
            applicationTokens: selection.applicationTokens,
            categoryTokens: selection.categoryTokens,
            webDomainTokens: selection.webDomainTokens,
            allCategoriesThreshold: allCategoriesThreshold
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
        case allExcept
        case specific
    }

    enum WebDomainPolicyCase: Equatable {
        case none
        case all
        case specific
    }

    struct DecisionShape: Equatable {
        let applicationCategories: ApplicationPolicyCase
        let webDomainCategories: WebDomainPolicyCase
        /// Whether `store.shield.applications` gets written with the
        /// selection's `applicationTokens`. `false` means the tokens flow
        /// through an `except:` parameter instead (or there are no apps).
        let writesSpecificApplicationsChannel: Bool
        /// Whether `store.shield.webDomains` gets written with the
        /// selection's `webDomainTokens`.
        let writesSpecificWebDomainsChannel: Bool
    }

    /// Pure, count-driven mapping that tests can drive with plain `Int`s.
    ///
    /// Matches the value-aware ``decide(applicationTokens:categoryTokens:webDomainTokens:allCategoriesThreshold:)``
    /// implementation step-for-step so the two stay in lockstep.
    static func decideShape(
        applicationTokenCount: Int,
        categoryTokenCount: Int,
        webDomainTokenCount: Int,
        allCategoriesThreshold: Int
    ) -> DecisionShape {
        let hasAllCategories = categoryTokenCount >= allCategoriesThreshold
        let hasAnyCategory = categoryTokenCount > 0
        let hasApps = applicationTokenCount > 0
        let hasWebDomains = webDomainTokenCount > 0

        let applicationCategories: ApplicationPolicyCase
        let writesApplicationsChannel: Bool

        if hasAllCategories {
            applicationCategories = .allExcept
            writesApplicationsChannel = false
        } else if hasAnyCategory {
            applicationCategories = .specific
            writesApplicationsChannel = hasApps
        } else {
            applicationCategories = .none
            writesApplicationsChannel = hasApps
        }

        let webDomainCategories: WebDomainPolicyCase
        if hasAllCategories {
            webDomainCategories = .all
        } else if hasAnyCategory {
            webDomainCategories = .specific
        } else {
            webDomainCategories = .none
        }

        return DecisionShape(
            applicationCategories: applicationCategories,
            webDomainCategories: webDomainCategories,
            writesSpecificApplicationsChannel: writesApplicationsChannel,
            writesSpecificWebDomainsChannel: hasWebDomains
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
        case .allExcept(let exceptions):
            store.shield.applicationCategories = .all(except: exceptions)
        case .specific(let categories):
            store.shield.applicationCategories = .specific(categories)
        }

        switch decision.webDomainCategories {
        case .none:
            store.shield.webDomainCategories = nil
        case .all:
            store.shield.webDomainCategories = .all(except: [])
        case .specific(let categories):
            store.shield.webDomainCategories = .specific(categories)
        }

        store.shield.applications = decision.specificApplications
        store.shield.webDomains = decision.specificWebDomains
    }
}
