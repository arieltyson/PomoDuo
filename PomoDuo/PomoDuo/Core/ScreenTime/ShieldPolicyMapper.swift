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
/// ### Category exceptions (a separate, opt-in input)
///
/// `FamilyActivitySelection` cannot encode "user picked a category but
/// deselected one app inside it" — the struct has no exceptions field
/// (verified against Apple's public API surface). When the picker
/// observes that flow on device, it demotes the category: it removes the
/// category from `categoryTokens` and emits a partial `applicationTokens`
/// containing only the apps the picker enumerated minus the deselected
/// one. Under a pure inclusive mapping that loses the entire category
/// shield and unblocks every category app the picker did not enumerate.
///
/// To honor the user's actual intent ("shield this category, but exempt
/// this one app"), ``ScreenTimeManager`` derives a separate
/// `categoryExceptions` set at commit time by diffing the new draft
/// against the previously-committed selection, and threads it into this
/// mapper as a *distinct* input. When `categoryExceptions` is non-empty
/// **and** `categoryTokens` is non-empty, the mapper emits Apple's
/// `ShieldSettings.ActivityCategoryPolicy.specific(_:except:)` — exactly
/// the shape Apple documents for "shield these categories, with these
/// specific apps exempted".
///
/// This is *not* a reintroduction of the old wrong "applicationTokens
/// are exceptions" interpretation. `applicationTokens` is still treated
/// inclusively (apps the user picked to shield); `categoryExceptions` is
/// a separate input derived at commit time from the user's edit history,
/// not from raw picker output.
///
/// ### What changed from the previous mapper
///
/// The previous mapper rewrite collapsed exception cases entirely under
/// the (correct) reading that `applicationTokens` is inclusive. That
/// fixed the original "blocking doesn't work" bug but left no path to
/// express category-with-exception intent. This pass re-adds the
/// `.specificExcept` case as a separate, opt-in path triggered only when
/// the explicit `categoryExceptions` input is non-empty.
enum ShieldPolicyMapper {

    /// Application-side category policy derived from a selection.
    ///
    /// `.specific(_)` is the inclusive case used when the user picked one
    /// or more categories with no exception list. `.specificExcept(_, _)`
    /// is used when the caller derived a non-empty `categoryExceptions`
    /// set (see ``ScreenTimeManager/commitDraft(_:)``); it maps to
    /// Apple's `ActivityCategoryPolicy.specific(_:except:)` which shields
    /// the listed categories but exempts the listed app tokens.
    enum ApplicationCategoryPolicy: Equatable {
        case none
        case specific(Set<ActivityCategoryToken>)
        case specificExcept(Set<ActivityCategoryToken>, Set<ApplicationToken>)
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
    /// The base mapping is a straight inclusive read of the selection.
    /// `categoryExceptions` is the only non-inclusive input: when
    /// non-empty *and* `categoryTokens` is non-empty, those tokens are
    /// exempted from the category shield via
    /// `ActivityCategoryPolicy.specific(_:except:)`. Apple caps that
    /// policy's exception list at 50 tokens; callers should respect the
    /// limit (``ScreenTimeManager/commitDraft(_:)`` handles the cap by
    /// dropping exception preservation when it's exceeded).
    ///
    /// When `categoryExceptions` is non-empty but `categoryTokens` is
    /// empty, the exceptions input is silently ignored — there is no
    /// category shield to except *from*, so the only meaningful write
    /// is the specific-apps channel and the exceptions concept doesn't
    /// apply.
    static func decide(
        applicationTokens: Set<ApplicationToken>,
        categoryTokens: Set<ActivityCategoryToken>,
        webDomainTokens: Set<WebDomainToken>,
        categoryExceptions: Set<ApplicationToken> = []
    ) -> Decision {
        let applicationCategories: ApplicationCategoryPolicy
        if categoryTokens.isEmpty {
            applicationCategories = .none
        } else if categoryExceptions.isEmpty {
            applicationCategories = .specific(categoryTokens)
        } else {
            applicationCategories = .specificExcept(
                categoryTokens,
                categoryExceptions
            )
        }

        // Web-domain categories don't currently support an exceptions
        // path through this mapper — the picker doesn't emit a
        // discoverable web-domain partial-deselect signal in the same
        // shape, and the user's reported failure mode is app-side. Web
        // category exceptions can be added the same way later if the
        // pattern surfaces.
        let webDomainCategories: WebDomainCategoryPolicy =
            categoryTokens.isEmpty ? .none : .specific(categoryTokens)

        // When the user's draft has the deselected app removed, the
        // app token won't be in `applicationTokens` either — but if it
        // somehow is (e.g., picker keeping the token despite demotion),
        // strip it from the specific-apps write so the exception
        // semantic isn't undone by the apps channel re-shielding it.
        let effectiveApplications = applicationTokens.subtracting(
            categoryExceptions
        )

        return Decision(
            applicationCategories: applicationCategories,
            webDomainCategories: webDomainCategories,
            specificApplications: effectiveApplications.isEmpty
                ? nil : effectiveApplications,
            specificWebDomains: webDomainTokens.isEmpty ? nil : webDomainTokens
        )
    }

    /// Convenience for `FamilyActivitySelection` callers.
    static func decide(
        for selection: FamilyActivitySelection,
        categoryExceptions: Set<ApplicationToken> = []
    ) -> Decision {
        decide(
            applicationTokens: selection.applicationTokens,
            categoryTokens: selection.categoryTokens,
            webDomainTokens: selection.webDomainTokens,
            categoryExceptions: categoryExceptions
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
        case specificExcept
    }

    enum WebDomainPolicyCase: Equatable {
        case none
        case specific
    }

    struct DecisionShape: Equatable {
        let applicationCategories: ApplicationPolicyCase
        let webDomainCategories: WebDomainPolicyCase
        /// Whether `store.shield.applications` gets written with the
        /// selection's `applicationTokens` (minus category exceptions).
        let writesSpecificApplicationsChannel: Bool
        /// Whether `store.shield.webDomains` gets written with the
        /// selection's `webDomainTokens`.
        let writesSpecificWebDomainsChannel: Bool
    }

    /// Pure, count-driven mapping that tests can drive with plain `Int`s.
    ///
    /// Matches ``decide(applicationTokens:categoryTokens:webDomainTokens:categoryExceptions:)``
    /// step-for-step so the two stay in lockstep.
    static func decideShape(
        applicationTokenCount: Int,
        categoryTokenCount: Int,
        webDomainTokenCount: Int,
        categoryExceptionCount: Int = 0
    ) -> DecisionShape {
        let applicationCategories: ApplicationPolicyCase
        if categoryTokenCount == 0 {
            applicationCategories = .none
        } else if categoryExceptionCount == 0 {
            applicationCategories = .specific
        } else {
            applicationCategories = .specificExcept
        }

        let webDomainCategories: WebDomainPolicyCase =
            categoryTokenCount == 0 ? .none : .specific

        // Matches the value-aware decide() exception-stripping behavior:
        // exception tokens are removed from the specific-apps channel so
        // the channel write doesn't undo the exception. We can't detect
        // that subtraction from counts alone, so the shape's
        // `writesSpecificApplicationsChannel` reports whether *any* apps
        // remain after the assumption that exception tokens were a
        // subset of `applicationTokenCount`.
        let effectiveAppsCount = max(
            0,
            applicationTokenCount - categoryExceptionCount
        )

        return DecisionShape(
            applicationCategories: applicationCategories,
            webDomainCategories: webDomainCategories,
            writesSpecificApplicationsChannel: effectiveAppsCount > 0,
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
        case .specificExcept(let categories, let exceptions):
            store.shield.applicationCategories = .specific(
                categories,
                except: exceptions
            )
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
