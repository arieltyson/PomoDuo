import Foundation
import Testing

@testable import PomoDuo

struct DeepLinkRouterTests {

    // MARK: - Custom Scheme Routing

    @Test func customSchemeAddFriend() {
        let url = URL(string: "pomoduo://add-friend/arieltyson")!
        let route = DeepLinkRouter.route(from: url)
        #expect(route == .addFriend("arieltyson"))
    }

    @Test func customSchemeAddFriendNormalizesCase() {
        let url = URL(string: "pomoduo://add-friend/ArielTyson")!
        let route = DeepLinkRouter.route(from: url)
        #expect(route == .addFriend("arieltyson"))
    }

    @Test func customSchemeTimer() {
        let url = URL(string: "pomoduo://timer")!
        #expect(DeepLinkRouter.route(from: url) == .timer)
    }

    @Test func customSchemePartner() {
        let url = URL(string: "pomoduo://partner")!
        #expect(DeepLinkRouter.route(from: url) == .partner)
    }

    @Test func customSchemeFriendRequest() {
        let url = URL(string: "pomoduo://friend-request/abc123")!
        #expect(DeepLinkRouter.route(from: url) == .friendRequest("abc123"))
    }

    @Test func customSchemePairCode() {
        let url = URL(string: "pomoduo://pair/abc123")!
        #expect(DeepLinkRouter.route(from: url) == .pair("ABC123"))
    }

    @Test func customSchemeUnknownRoute() {
        let url = URL(string: "pomoduo://unknown")!
        #expect(DeepLinkRouter.route(from: url) == nil)
    }

    // MARK: - Universal Link Routing

    @Test func universalLinkAddFriend() {
        let url = URL(string: "https://pomoduo-61e38.web.app/add-friend/arieltyson")!
        let route = DeepLinkRouter.route(from: url)
        #expect(route == .addFriend("arieltyson"))
    }

    @Test func universalLinkAddFriendNormalizesCase() {
        let url = URL(string: "https://pomoduo-61e38.web.app/add-friend/Mahim")!
        #expect(DeepLinkRouter.route(from: url) == .addFriend("mahim"))
    }

    @Test func universalLinkPairCode() {
        let url = URL(string: "https://pomoduo-61e38.web.app/pair/xyz789")!
        #expect(DeepLinkRouter.route(from: url) == .pair("XYZ789"))
    }

    @Test func universalLinkFriendRequest() {
        let url = URL(string: "https://pomoduo-61e38.web.app/friend-request/req456")!
        #expect(DeepLinkRouter.route(from: url) == .friendRequest("req456"))
    }

    @Test func universalLinkUnknownRoute() {
        let url = URL(string: "https://pomoduo-61e38.web.app/unknown/path")!
        #expect(DeepLinkRouter.route(from: url) == nil)
    }

    @Test func universalLinkWrongDomain() {
        let url = URL(string: "https://evil.com/add-friend/arieltyson")!
        #expect(DeepLinkRouter.route(from: url) == nil)
    }

    @Test func unrelatedHTTPSURL() {
        let url = URL(string: "https://apple.com")!
        #expect(DeepLinkRouter.route(from: url) == nil)
    }

    @Test func unrelatedScheme() {
        let url = URL(string: "mailto:test@example.com")!
        #expect(DeepLinkRouter.route(from: url) == nil)
    }

    // MARK: - URL Builders

    @Test func addFriendURLFormat() {
        let url = DeepLinkRouter.addFriendURL(username: "arieltyson")
        #expect(url.absoluteString == "https://pomoduo-61e38.web.app/add-friend/arieltyson")
    }

    @Test func pairURLFormat() {
        let url = DeepLinkRouter.pairURL(code: "ABC123")
        #expect(url.absoluteString == "https://pomoduo-61e38.web.app/pair/ABC123")
    }

    @Test func addFriendURLRoundTrips() {
        let url = DeepLinkRouter.addFriendURL(username: "mahim")
        let route = DeepLinkRouter.route(from: url)
        #expect(route == .addFriend("mahim"))
    }

    @Test func pairURLRoundTrips() {
        let url = DeepLinkRouter.pairURL(code: "XYZ789")
        let route = DeepLinkRouter.route(from: url)
        #expect(route == .pair("XYZ789"))
    }

    // MARK: - Edge Cases

    @Test func addFriendMissingUsername() {
        let url = URL(string: "pomoduo://add-friend")!
        #expect(DeepLinkRouter.route(from: url) == nil)
    }

    @Test func pairMissingCode() {
        let url = URL(string: "pomoduo://pair")!
        #expect(DeepLinkRouter.route(from: url) == nil)
    }

    @Test func httpUniversalLinkAlsoWorks() {
        let url = URL(string: "http://pomoduo-61e38.web.app/add-friend/test")!
        #expect(DeepLinkRouter.route(from: url) == .addFriend("test"))
    }

    // MARK: - Empty / Whitespace Param Hardening
    //
    // These tests pin the router's behavior for the malformed link
    // shapes that produced the original `FIRInvalidArgumentException:
    // Document path cannot be empty.` crash. The router must reject
    // every shape that would otherwise propagate an empty/whitespace
    // username into ``FirebaseFriendService.searchByUsername(_:)``.

    @Test("Custom-scheme add-friend with trailing slash routes to nil")
    func customSchemeAddFriendTrailingSlashRoutesToNil() {
        let url = URL(string: "pomoduo://add-friend/")!
        #expect(DeepLinkRouter.route(from: url) == nil)
    }

    @Test("Universal Link add-friend with trailing slash routes to nil")
    func universalLinkAddFriendTrailingSlashRoutesToNil() {
        let url = URL(string: "https://pomoduo-61e38.web.app/add-friend/")!
        #expect(DeepLinkRouter.route(from: url) == nil)
    }

    @Test("Custom-scheme pair with trailing slash routes to nil")
    func customSchemePairTrailingSlashRoutesToNil() {
        let url = URL(string: "pomoduo://pair/")!
        #expect(DeepLinkRouter.route(from: url) == nil)
    }

    @Test("Universal Link friend-request with trailing slash routes to nil")
    func universalLinkFriendRequestTrailingSlashRoutesToNil() {
        let url = URL(string: "https://pomoduo-61e38.web.app/friend-request/")!
        #expect(DeepLinkRouter.route(from: url) == nil)
    }

    /// Percent-encoded whitespace as the entire username is a real
    /// shape iMessage / iCloud share-sheet rewrites have been seen to
    /// produce. The router must trim and reject it.
    @Test("Whitespace-only add-friend param routes to nil")
    func universalLinkAddFriendWhitespaceParamRoutesToNil() {
        let url = URL(
            string: "https://pomoduo-61e38.web.app/add-friend/%20%20"
        )!
        #expect(DeepLinkRouter.route(from: url) == nil)
    }

    @Test("Whitespace-only pair param routes to nil")
    func universalLinkPairWhitespaceParamRoutesToNil() {
        let url = URL(string: "https://pomoduo-61e38.web.app/pair/%20")!
        #expect(DeepLinkRouter.route(from: url) == nil)
    }

    @Test("Whitespace-only friend-request param routes to nil")
    func universalLinkFriendRequestWhitespaceParamRoutesToNil() {
        let url = URL(
            string: "https://pomoduo-61e38.web.app/friend-request/%20"
        )!
        #expect(DeepLinkRouter.route(from: url) == nil)
    }

    /// The router must never emit `.addFriend("")` even via direct
    /// resolveRoute paths — pinning this in case a future refactor
    /// adds another way to construct the route.
    @Test("Router never produces .addFriend with empty payload")
    func addFriendEmptyPayloadIsImpossibleViaRouter() {
        // Custom scheme without param at all (already covered, kept
        // here for completeness next to the new hardening tests).
        let noParamCustom = URL(string: "pomoduo://add-friend")!
        // Trailing slash without payload.
        let trailingSlashCustom = URL(string: "pomoduo://add-friend/")!
        let trailingSlashHTTPS = URL(
            string: "https://pomoduo-61e38.web.app/add-friend/"
        )!

        #expect(DeepLinkRouter.route(from: noParamCustom) == nil)
        #expect(DeepLinkRouter.route(from: trailingSlashCustom) == nil)
        #expect(DeepLinkRouter.route(from: trailingSlashHTTPS) == nil)
    }
}

// MARK: - UsernameNormalizer

/// Coverage for the single source of truth used by every layer
/// (router, view-layer ingress, Firestore service) to enforce the
/// "non-empty normalized username" precondition.
struct UsernameNormalizerTests {

    @Test("Empty string normalizes to nil")
    func emptyStringIsNil() {
        #expect(UsernameNormalizer.normalize("") == nil)
    }

    @Test("Whitespace-only string normalizes to nil")
    func whitespaceOnlyIsNil() {
        #expect(UsernameNormalizer.normalize("   ") == nil)
        #expect(UsernameNormalizer.normalize("\t\n") == nil)
    }

    @Test("Surrounding whitespace is trimmed")
    func surroundingWhitespaceIsTrimmed() {
        #expect(UsernameNormalizer.normalize("  ariel  ") == "ariel")
    }

    @Test("Mixed-case input is lowercased")
    func mixedCaseIsLowercased() {
        #expect(UsernameNormalizer.normalize("ArielTyson") == "arieltyson")
    }

    @Test("Already-normalized input round-trips unchanged")
    func canonicalRoundTrips() {
        #expect(UsernameNormalizer.normalize("mahim") == "mahim")
    }

    @Test("Optional nil input normalizes to nil")
    func optionalNilIsNil() {
        let raw: String? = nil
        #expect(UsernameNormalizer.normalize(raw) == nil)
    }

    @Test("isUsable matches normalize's nullity")
    func isUsableMatchesNormalize() {
        #expect(UsernameNormalizer.isUsable("ariel"))
        #expect(UsernameNormalizer.isUsable("") == false)
        #expect(UsernameNormalizer.isUsable("   ") == false)
        #expect(UsernameNormalizer.isUsable(nil) == false)
    }
}
