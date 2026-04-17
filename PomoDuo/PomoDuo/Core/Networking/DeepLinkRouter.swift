import Foundation

/// Centralized deep-link routing for both custom URL schemes and Universal Links.
///
/// Handles two URL formats:
/// - **Custom scheme**: `pomoduo://add-friend/{username}`
/// - **Universal Link**: `https://pomoduo-61e38.web.app/add-friend/{username}`
///
/// The domain must match:
/// - The `applinks:` entry in `PomoDuo.entitlements`
/// - The `apple-app-site-association` file hosted on the web server
/// - The `Associated Domains` capability in Xcode
nonisolated enum DeepLinkRouter {

    /// The web domain serving the `apple-app-site-association` file.
    ///
    /// Uses Firebase Hosting's free default domain. To use a custom domain
    /// (e.g., `pomoduo.app`), update this constant and add the domain in
    /// both Firebase Hosting and the `Associated Domains` entitlement.
    static let domain = "pomoduo-61e38.web.app"

    /// The App Store product URL for fallback when the app is not installed.
    static let appStoreURL = URL(
        string: "https://apps.apple.com/app/pomo-duo/id6759349583"
    )!

    // MARK: - URL Builders

    /// Builds an HTTPS Universal Link for the add-friend flow.
    static func addFriendURL(username: String) -> URL {
        URL(string: "https://\(domain)/add-friend/\(username)")!
    }

    /// Builds an HTTPS Universal Link for the pair-code flow.
    static func pairURL(code: String) -> URL {
        URL(string: "https://\(domain)/pair/\(code)")!
    }

    // MARK: - Routing

    /// Parses a deep-link URL into a typed route.
    ///
    /// Supports both the custom `pomoduo://` scheme and HTTPS Universal
    /// Links. Returns `nil` for unrecognized URLs.
    static func route(from url: URL) -> DeepLinkRoute? {
        if url.scheme == "pomoduo" {
            return routeFromCustomScheme(url)
        }

        if isUniversalLink(url) {
            return routeFromUniversalLink(url)
        }

        return nil
    }

    // MARK: - Private

    private static func isUniversalLink(_ url: URL) -> Bool {
        guard url.scheme == "https" || url.scheme == "http",
            let host = url.host()
        else { return false }
        return host == domain
    }

    /// Custom scheme: `pomoduo://{route}/{param}`
    private static func routeFromCustomScheme(_ url: URL) -> DeepLinkRoute? {
        let routeName = url.host()
        let param = url.pathComponents.dropFirst().first

        return resolveRoute(name: routeName, param: param)
    }

    /// Universal Link: `https://{domain}/{route}/{param}`
    private static func routeFromUniversalLink(_ url: URL) -> DeepLinkRoute? {
        let components = Array(url.pathComponents.dropFirst())
        let routeName = components.first
        let param = components.dropFirst().first

        return resolveRoute(name: routeName, param: param)
    }

    private static func resolveRoute(
        name: String?,
        param: String?
    ) -> DeepLinkRoute? {
        // Trailing-slash URLs (`pomoduo://add-friend/`,
        // `https://…/add-friend/`) and certain iMessage/iCloud
        // rewrites can produce a non-`nil` *empty-or-whitespace*
        // `param`. `Optional.map` only filters `nil`, so without an
        // emptiness check the router would emit `.addFriend("")`,
        // which crashes Firestore when the receiver dereferences it
        // via `.document(normalized)`. Reject empty params here so
        // every downstream layer can assume the param is meaningful.
        switch name {
        case "timer":
            return .timer
        case "partner":
            return .partner
        case "friend-request":
            return nonEmpty(param).map { .friendRequest($0) }
        case "pair":
            return nonEmpty(param).map { .pair($0.uppercased()) }
        case "add-friend":
            return nonEmpty(param).map { .addFriend($0.lowercased()) }
        default:
            return nil
        }
    }

    /// Returns the trimmed `value` if it has any non-whitespace
    /// content; `nil` otherwise. Used by ``resolveRoute(name:param:)``
    /// to refuse routing for malformed deep links before they can
    /// reach view-layer / service-layer code.
    private static func nonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

/// Parsed deep-link destination.
nonisolated enum DeepLinkRoute: Equatable, Sendable {
    case timer
    case partner
    case friendRequest(String)
    case pair(String)
    case addFriend(String)
}
