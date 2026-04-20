import FamilyControls
import ManagedSettings

/// Translates a `FamilyActivitySelection` into the shield writes PomoDuo uses.
enum ShieldPolicyMapper {

    enum ApplicationCategoryPolicy: Equatable {
        case none
        case specific(Set<ActivityCategoryToken>)
        case specificExcept(Set<ActivityCategoryToken>, Set<ApplicationToken>)
    }

    enum WebDomainCategoryPolicy: Equatable {
        case none
        case specific(Set<ActivityCategoryToken>)
        case specificExcept(Set<ActivityCategoryToken>, Set<WebDomainToken>)
    }

    struct Decision: Equatable {
        let applicationCategories: ApplicationCategoryPolicy
        let webDomainCategories: WebDomainCategoryPolicy
        let specificApplications: Set<ApplicationToken>?
        let specificWebDomains: Set<WebDomainToken>?
    }

    static func decide(
        applicationTokens: Set<ApplicationToken>,
        categoryTokens: Set<ActivityCategoryToken>,
        webDomainTokens: Set<WebDomainToken>,
        categoryExceptions: Set<ApplicationToken> = [],
        webDomainCategoryExceptions: Set<WebDomainToken> = []
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

        let webDomainCategories: WebDomainCategoryPolicy
        if categoryTokens.isEmpty {
            webDomainCategories = .none
        } else if webDomainCategoryExceptions.isEmpty {
            webDomainCategories = .specific(categoryTokens)
        } else {
            webDomainCategories = .specificExcept(
                categoryTokens,
                webDomainCategoryExceptions
            )
        }

        return Decision(
            applicationCategories: applicationCategories,
            webDomainCategories: webDomainCategories,
            specificApplications: applicationTokens.isEmpty
                ? nil : applicationTokens,
            specificWebDomains: webDomainTokens.isEmpty
                ? nil : webDomainTokens
        )
    }

    static func decide(
        for selection: FamilyActivitySelection,
        categoryExceptions: Set<ApplicationToken> = [],
        webDomainCategoryExceptions: Set<WebDomainToken> = []
    ) -> Decision {
        decide(
            applicationTokens: selection.applicationTokens,
            categoryTokens: selection.categoryTokens,
            webDomainTokens: selection.webDomainTokens,
            categoryExceptions: categoryExceptions,
            webDomainCategoryExceptions: webDomainCategoryExceptions
        )
    }

    enum ApplicationPolicyCase: Equatable {
        case none
        case specific
        case specificExcept
    }

    enum WebDomainPolicyCase: Equatable {
        case none
        case specific
        case specificExcept
    }

    struct DecisionShape: Equatable {
        let applicationCategories: ApplicationPolicyCase
        let webDomainCategories: WebDomainPolicyCase
        let writesSpecificApplicationsChannel: Bool
        let writesSpecificWebDomainsChannel: Bool
    }

    static func decideShape(
        applicationTokenCount: Int,
        categoryTokenCount: Int,
        webDomainTokenCount: Int,
        categoryExceptionCount: Int = 0,
        webDomainCategoryExceptionCount: Int = 0
    ) -> DecisionShape {
        let applicationCategories: ApplicationPolicyCase
        if categoryTokenCount == 0 {
            applicationCategories = .none
        } else if categoryExceptionCount == 0 {
            applicationCategories = .specific
        } else {
            applicationCategories = .specificExcept
        }

        let webDomainCategories: WebDomainPolicyCase
        if categoryTokenCount == 0 {
            webDomainCategories = .none
        } else if webDomainCategoryExceptionCount == 0 {
            webDomainCategories = .specific
        } else {
            webDomainCategories = .specificExcept
        }

        return DecisionShape(
            applicationCategories: applicationCategories,
            webDomainCategories: webDomainCategories,
            writesSpecificApplicationsChannel: applicationTokenCount > 0,
            writesSpecificWebDomainsChannel: webDomainTokenCount > 0
        )
    }

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
        case .specificExcept(let categories, let exceptions):
            store.shield.webDomainCategories = .specific(
                categories,
                except: exceptions
            )
        }

        store.shield.applications = decision.specificApplications
        store.shield.webDomains = decision.specificWebDomains
    }
}
