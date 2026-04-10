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
}
