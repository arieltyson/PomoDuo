import Foundation

/// Pure helper that preserves category intent when a picker draft removes
/// individual items from a previously selected category.
struct CategoryExceptionResolution<Category: Hashable, Item: Hashable>:
    Equatable
{
    let categories: Set<Category>
    let exceptions: Set<Item>
}

enum CategoryExceptionResolver {
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
