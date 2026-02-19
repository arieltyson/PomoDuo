import Foundation
import Testing

@testable import PomoDuo

@Suite("Launch Phase Tests")
@MainActor
struct LaunchPhaseTests {

    @Test func authManagerStartsInUnknownState() {
        let manager = AuthManager()
        #expect(manager.authState == .unknown)
        #expect(manager.currentUserID == nil)
    }

    @Test func skeletonTabViewCanBeCreated() {
        // Verifies the skeleton compiles and initializes without crash.
        _ = SkeletonTabView()
    }
}
