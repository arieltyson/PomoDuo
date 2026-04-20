import Foundation

/// Pure helper that preserves category intent when a picker draft removes
/// individual items from a previously selected category.
///
/// Explicitly `nonisolated` because this type holds only value-type state
/// and has no ties to UI, `ManagedSettings`, `FamilyControls`, or
/// persistence. The app target sets `SWIFT_DEFAULT_ACTOR_ISOLATION =
/// MainActor`, which would otherwise infer `@MainActor` here and prevent
/// pure computations from running in synchronous, nonisolated contexts
/// (e.g. the test target and any future off-main caller).
nonisolated struct CategoryExceptionResolution<Category: Hashable, Item: Hashable>:
    Equatable
{
    let categories: Set<Category>
    let exceptions: Set<Item>
}

nonisolated enum CategoryExceptionResolver {
    static func resolve<Category: Hashable, Item: Hashable>(
        previousCategories: Set<Category>,
        previousItems: Set<Item>,
        previousExceptions: Set<Item>,
        draftCategories: Set<Category>,
        draftItems: Set<Item>,
        restoresLostCategories: Bool
    ) -> CategoryExceptionResolution<Category, Item> {
        let categories = restoresLostCategories
            ? draftCategories.union(
                previousCategories.subtracting(draftCategories)
            )
            : draftCategories

        guard !categories.isEmpty else {
            return CategoryExceptionResolution(
                categories: categories,
                exceptions: []
            )
        }

        let removedItems = previousItems.subtracting(draftItems)
        let exceptions = previousExceptions
            .union(removedItems)
            .subtracting(draftItems)

        return CategoryExceptionResolution(
            categories: categories,
            exceptions: exceptions
        )
    }
}
