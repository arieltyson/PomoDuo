import Foundation
import Testing

@testable import PomoDuo

@MainActor
struct FocusStatsSnapshotTests {
    @Test func emptySnapshotHasZeroValues() {
        let snapshot = FocusStatsSnapshot.empty(now: .distantPast)
        #expect(snapshot.todayMinutes == 0)
        #expect(snapshot.todaySessionCount == 0)
        #expect(snapshot.currentStreak == 0)
    }

    @Test func previewSnapshotHasExpectedSampleValues() {
        let snapshot = FocusStatsSnapshot.preview
        #expect(snapshot.todayMinutes == 75)
        #expect(snapshot.todaySessionCount == 3)
        #expect(snapshot.currentStreak == 5)
    }
}

@MainActor
struct FocusWidgetKindTests {
    @Test func statsKindIsStable() {
        #expect(FocusWidgetKind.stats == "FocusStatsWidget")
    }
}

@MainActor
struct WidgetDataProviderTests {
    @Test func appGroupIDIsStable() {
        #expect(
            WidgetDataProvider.appGroupID
                == StorageConfiguration.widgetAppGroupID
        )
    }

    @Test func readSnapshotNoCrashesWithoutGroupEntitlement() {
        let snapshot = WidgetDataProvider.readSnapshot(now: .now)
        #expect(snapshot.todayMinutes >= 0)
        #expect(snapshot.todaySessionCount >= 0)
        #expect(snapshot.currentStreak >= 0)
    }

    @Test func updateNoCrashesWithoutGroupEntitlement() {
        WidgetDataProvider.update(
            todayMinutes: 40,
            todaySessionCount: 2,
            currentStreak: 3
        )
    }
}
