import Foundation
import Testing

@testable import PomoDuo

@Suite("SessionHistory User Scope")
@MainActor
struct SessionHistoryUserScopeTests {
    private func makeSession(
        userID: String?,
        focusDuration: TimeInterval = 25 * 60,
        startedAt: Date = .now
    ) -> CompletedSession {
        CompletedSession(
            startedAt: startedAt,
            focusDuration: focusDuration,
            roundNumber: 1,
            totalRounds: 4,
            sessionType: .solo,
            userID: userID
        )
    }

    @Test("nil user scope includes all sessions")
    func nilScopeIncludesAll() {
        let viewModel = SessionHistoryViewModel()
        let sessions = [
            makeSession(userID: "alice"),
            makeSession(userID: "bob"),
            makeSession(userID: nil),
        ]

        viewModel.refresh(from: sessions, userID: nil)

        #expect(viewModel.allTimeSessionCount == 3)
    }

    @Test("user scope includes matching and legacy sessions")
    func userScopeIncludesMatchingAndLegacy() {
        let viewModel = SessionHistoryViewModel()
        let sessions = [
            makeSession(userID: "alice"),
            makeSession(userID: "bob"),
            makeSession(userID: nil),
        ]

        viewModel.refresh(from: sessions, userID: "alice")

        #expect(viewModel.allTimeSessionCount == 2)
    }

    @Test("user scope excludes sessions from other users")
    func userScopeExcludesOthers() {
        let viewModel = SessionHistoryViewModel()
        let sessions = [
            makeSession(userID: "bob", focusDuration: 25 * 60),
            makeSession(userID: "charlie", focusDuration: 50 * 60),
        ]

        viewModel.refresh(from: sessions, userID: "alice")

        #expect(viewModel.allTimeSessionCount == 0)
        #expect(viewModel.allTimeFocusMinutes == 0)
        #expect(viewModel.currentStreak == 0)
    }

    @Test("focus totals are scoped to current user")
    func totalsAreScoped() {
        let viewModel = SessionHistoryViewModel()
        let sessions = [
            makeSession(userID: "alice", focusDuration: 25 * 60),
            makeSession(userID: "alice", focusDuration: 50 * 60),
            makeSession(userID: "bob", focusDuration: 100 * 60),
        ]

        viewModel.refresh(from: sessions, userID: "alice")

        #expect(viewModel.allTimeFocusMinutes == 75)
        #expect(viewModel.allTimeSessionCount == 2)
    }

    @Test("streak respects scoped sessions")
    func streakRespectsScope() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        guard
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today)
        else {
            Issue.record("Unable to build test date")
            return
        }

        let sessions = [
            makeSession(userID: "alice", startedAt: today),
            makeSession(userID: "alice", startedAt: yesterday),
            makeSession(userID: "bob", startedAt: today),
        ]

        let viewModel = SessionHistoryViewModel()
        viewModel.refresh(from: sessions, userID: "alice")

        #expect(viewModel.currentStreak == 2)
    }

    @Test("weekly summaries only include scoped sessions")
    func weeklySummariesScoped() {
        let viewModel = SessionHistoryViewModel()
        let sessions = [
            makeSession(userID: "alice", focusDuration: 25 * 60),
            makeSession(userID: "bob", focusDuration: 25 * 60),
        ]

        viewModel.refresh(from: sessions, userID: "alice")
        let totalWeeklyMinutes = viewModel.weeklySummaries.reduce(0) {
            partial,
            summary in
            partial + summary.totalMinutes
        }

        #expect(totalWeeklyMinutes == 25)
    }

    @Test("completed session stores user ID")
    func completedSessionStoresUserID() {
        let session = makeSession(userID: "user-test")
        #expect(session.userID == "user-test")
    }

    @Test("completed session defaults user ID to nil")
    func completedSessionDefaultsUserIDToNil() {
        let session = CompletedSession(
            focusDuration: 25 * 60,
            roundNumber: 1,
            totalRounds: 4
        )

        #expect(session.userID == nil)
    }
}
